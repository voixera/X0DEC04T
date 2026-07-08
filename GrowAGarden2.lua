-- X0DEC04T Hub for Grow a Garden 2
-- Full working version with guaranteed UI

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

-- ======================
-- LOAD UI LIBRARY (FIXED)
-- ======================
local Rayfield
local function LoadUILibrary()
    local urls = {
        "https://raw.githubusercontent.com/shlexware/Rayfield/main/source",
        "https://sirius.menu/rayfield",
        "https://raw.githubusercontent.com/JustAPerson-Dev/Rayfield/main/source"
    }

    for _, url in ipairs(urls) do
        local ok, result = pcall(function()
            return loadstring(game:HttpGet(url, true))()
        end)
        if ok and result then
            return result
        end
    end

    -- Try with syn.request if available
    if syn and syn.request then
        for _, url in ipairs(urls) do
            local response = syn.request({Url = url, Method = "GET"})
            if response and response.StatusCode == 200 then
                local ok, result = pcall(function()
                    return loadstring(response.Body)()
                end)
                if ok and result then
                    return result
                end
            end
        end
    end

    return nil
end

Rayfield = LoadUILibrary()

if not Rayfield then
    -- Show Roblox notification if UI library fails
    pcall(function()
        Services.StarterGui:SetCore("SendNotification", {
            Title = "X0DEC04T Hub",
            Text = "Failed to load UI library. Check your internet connection and executor HTTP support.",
            Duration = 10
        })
    end)
    return
end

-- ======================
-- SCRIPT DATA & UTILITIES
-- ======================
local ScriptData = {
    Connections = {},
    Loops = {},
    ESPObjects = {},
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
    Plants = {}, Drops = {}, Remotes = {}, PlayerList = {},
    Plots = {}, SellArea = nil
}

-- ======================
-- PROTECTION FUNCTIONS
-- ======================
local function IsProtectedPath(instance)
    local current = instance
    local depth = 0
    while current and depth < 15 do
        if current.Name:lower():find("topbarplus")
            or current.Name:lower():find("clientmodules")
            or current.Name:lower():find("servertmodules")
            or current == Services.ReplicatedStorage
            or current == game:GetService("ServerScriptService")
        then
            return true
        end
        current = current.Parent
        depth = depth + 1
    end
    return false
end

local function SafeCall(fn)
    local ok, err = pcall(fn)
    if not ok then
        warn("[X0DEC04T Error]: " .. tostring(err))
    end
    return ok
end

local function AddConnection(name, connection)
    if ScriptData.Connections[name] then
        pcall(function() ScriptData.Connections[name]:Disconnect() end)
    end
    ScriptData.Connections[name] = connection
end

local function RemoveConnection(name)
    if ScriptData.Connections[name] then
        pcall(function() ScriptData.Connections[name]:Disconnect() end)
        ScriptData.Connections[name] = nil
    end
end

local function CreateLoop(name, func, wait_time)
    if ScriptData.Loops[name] then
        ScriptData.Loops[name] = false
        task.wait(0.1)
    end
    ScriptData.Loops[name] = true
    task.spawn(function()
        while ScriptData.Loops[name] do
            local ok, err = pcall(func)
            if not ok then warn("Loop Error [" .. name .. "]:", err) end
            task.wait(wait_time or 0.1)
        end
    end)
end

local function StopLoop(name)
    ScriptData.Loops[name] = false
end

-- ======================
-- GAME UTILITY FUNCTIONS
-- ======================
local function GetCharacter() return LocalPlayer.Character end
local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end
local function GetRootPart()
    local char = GetCharacter()
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

local function TeleportTo(position)
    local root = GetRootPart()
    if root then root.CFrame = CFrame.new(position) end
end

local function FindFirstDescendant(parent, name, className)
    if not parent or IsProtectedPath(parent) then return nil end
    for _, d in ipairs(parent:GetDescendants()) do
        if not IsProtectedPath(d) then
            local nameMatch = not name or d.Name:lower():find(name:lower())
            local classMatch = not className or d:IsA(className)
            if nameMatch and classMatch then return d end
        end
    end
    return nil
end

local function FindAllDescendants(parent, name, className)
    local results = {}
    if not parent or IsProtectedPath(parent) then return results end
    for _, d in ipairs(parent:GetDescendants()) do
        if not IsProtectedPath(d) then
            local nameMatch = not name or d.Name:lower():find(name:lower())
            local classMatch = not className or d:IsA(className)
            if nameMatch and classMatch then table.insert(results, d) end
        end
    end
    return results
end

local function GetRemote(name)
    if GameCache.Remotes[name] then return GameCache.Remotes[name] end
    local remote = FindFirstDescendant(Services.ReplicatedStorage, name, "RemoteEvent")
        or FindFirstDescendant(Services.ReplicatedStorage, name, "RemoteFunction")
    if remote then GameCache.Remotes[name] = remote end
    return remote
end

local function FireRemote(name, ...)
    local remote = GetRemote(name)
    if remote then
        pcall(function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer(...)
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer(...)
            end
        end)
        return true
    end
    return false
end

local function FindPlayerPlots()
    local plots = {}
    local parents = {
        workspace:FindFirstChild("PlayerPlots"),
        workspace:FindFirstChild("Plots"),
        workspace:FindFirstChild("Gardens"),
        workspace:FindFirstChild(LocalPlayer.Name)
    }
    for _, parent in ipairs(parents) do
        if parent then
            for _, obj in ipairs(parent:GetDescendants()) do
                if obj:IsA("Model") and (obj.Name:lower():find("plot") or obj:FindFirstChild("Soil") or obj:FindFirstChild("Plant")) then
                    table.insert(plots, obj)
                end
            end
        end
    end
    return plots
end

local function FindPlants()
    local plants = {}
    for _, plot in ipairs(FindPlayerPlots()) do
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

local function UpdateGameCache()
    task.spawn(function()
        GameCache.Garden = workspace:FindFirstChild("Garden") or workspace:FindFirstChild("PlayerGarden") or workspace:FindFirstChild("PlayerPlots")
        GameCache.Shop = workspace:FindFirstChild("Shop") or workspace:FindFirstChild("Store") or FindFirstDescendant(workspace, "shop", "Model")
        GameCache.SellArea = workspace:FindFirstChild("SellArea") or workspace:FindFirstChild("Sell") or FindFirstDescendant(workspace, "sell", "Model")
        GameCache.Spawn = workspace:FindFirstChild("SpawnLocation") or workspace:FindFirstChild("Spawn")
        GameCache.Plots = FindPlayerPlots()
        GameCache.Plants = FindPlants()
        GameCache.NPCs = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") and obj.Name:lower():find("npc") then
                table.insert(GameCache.NPCs, obj)
            end
        end
        GameCache.Drops = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and (obj.Name:lower():find("drop") or obj.Name:lower():find("coin") or obj.Name:lower():find("money")) then
                table.insert(GameCache.Drops, obj)
            end
        end
    end)
end

-- ======================
-- ESP SYSTEM
-- ======================
local function CreateESP(object, text, color)
    if not object then return end
    local key = tostring(object)
    if ScriptData.ESPObjects[key] then return end

    local targetPart = object
    if object:IsA("Model") then
        targetPart = object:FindFirstChild("HumanoidRootPart") or object:FindFirstChild("Head") or object:FindFirstChildWhichIsA("BasePart")
    end
    if not targetPart then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "X0D_ESP"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Parent = targetPart

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.5
    label.Text = text or object.Name
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = billboard

    ScriptData.ESPObjects[key] = billboard

    pcall(function()
        local highlight = Instance.new("Highlight")
        highlight.Name = "X0D_Highlight"
        highlight.FillColor = color or Color3.fromRGB(255, 255, 255)
        highlight.OutlineColor = color or Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.5
        highlight.Parent = object
        ScriptData.ESPObjects[key .. "_hl"] = highlight
    end)
end

local function RemoveESP(object)
    local key = tostring(object)
    if ScriptData.ESPObjects[key] then
        pcall(function() ScriptData.ESPObjects[key]:Destroy() end)
        ScriptData.ESPObjects[key] = nil
    end
    if ScriptData.ESPObjects[key .. "_hl"] then
        pcall(function() ScriptData.ESPObjects[key .. "_hl"]:Destroy() end)
        ScriptData.ESPObjects[key .. "_hl"] = nil
    end
end

local function ClearAllESP()
    for _, esp in pairs(ScriptData.ESPObjects) do
        pcall(function() esp:Destroy() end)
    end
    ScriptData.ESPObjects = {}
end

-- ======================
-- CONFIG SYSTEM
-- ======================
local function SaveConfig(profileName)
    profileName = profileName or "default"
    local fileName = "X0DEC04T_GAG2_" .. profileName .. ".json"
    local ok, result = pcall(function()
        return Services.HttpService:JSONEncode(ScriptData.Config)
    end)
    if ok and writefile then
        pcall(function() writefile(fileName, result) end)
        return true
    end
    return false
end

local function LoadConfig(profileName)
    profileName = profileName or "default"
    local fileName = "X0DEC04T_GAG2_" .. profileName .. ".json"
    if isfile and isfile(fileName) and readfile then
        local ok, result = pcall(function()
            return Services.HttpService:JSONDecode(readfile(fileName))
        end)
        if ok and result then
            for cat, settings in pairs(result) do
                if ScriptData.Config[cat] then
                    for k, v in pairs(settings) do
                        ScriptData.Config[cat][k] = v
                    end
                end
            end
            return true
        end
    end
    return false
end

local function Notify(title, content, duration)
    pcall(function()
        Rayfield:Notify({
            Title = title,
            Content = content,
            Duration = duration or 3
        })
    end)
end

-- ======================
-- CREATE WINDOW (GUARANTEED)
-- ======================
UpdateGameCache()

local Window
local success, err = pcall(function()
    Window = Rayfield:CreateWindow({
        Name = "X0DEC04T Hub | Grow a Garden 2",
        LoadingTitle = "X0DEC04T Hub",
        LoadingSubtitle = "Loading features...",
        ConfigurationSaving = {Enabled = false},
        KeySystem = false
    })
end)

if not Window then
    pcall(function()
        Services.StarterGui:SetCore("SendNotification", {
            Title = "X0DEC04T Hub",
            Text = "Failed to create window: " .. (err or "Unknown error"),
            Duration = 10
        })
    end)
    return
end

-- ======================
-- CREATE ALL TABS
-- ======================
local Tabs = {}
SafeCall(function() Tabs.Main = Window:CreateTab("Main", 4483362458) end)
SafeCall(function() Tabs.Player = Window:CreateTab("Player", 4483362458) end)
SafeCall(function() Tabs.Teleport = Window:CreateTab("Teleport", 4483362458) end)
SafeCall(function() Tabs.Visual = Window:CreateTab("Visual", 4483362458) end)
SafeCall(function() Tabs.Misc = Window:CreateTab("Misc", 4483362458) end)
SafeCall(function() Tabs.Settings = Window:CreateTab("Settings", 4483362458) end)
SafeCall(function() Tabs.Credits = Window:CreateTab("Credits", 4483362458) end)

-- ======================
-- MAIN TAB FEATURES
-- ======================
if Tabs.Main then
    SafeCall(function() Tabs.Main:CreateSection("Farming") end)

    -- Auto Harvest
    SafeCall(function()
        Tabs.Main:CreateToggle({
            Name = "Auto Harvest",
            CurrentValue = false,
            Flag = "AutoHarvest",
            Callback = function(value)
                ScriptData.Config.Main.AutoHarvest = value
                if value then
                    Notify("Auto Harvest", "Enabled", 2)
                    CreateLoop("AutoHarvest", function()
                        for _, plant in ipairs(FindPlants()) do
                            if plant and plant.Parent then
                                local ready = plant:FindFirstChild("Ready") or plant:FindFirstChild("Harvestable") or plant:FindFirstChild("Grown")
                                if ready and ready.Value == true then
                                    FireRemote("HarvestPlant", plant)
                                    FireRemote("Harvest", plant)
                                    FireRemote("harvest", plant)
                                end
                            end
                        end
                    end, 0.5)
                else
                    Notify("Auto Harvest", "Disabled", 2)
                    StopLoop("AutoHarvest")
                end
            end
        })
    end)

    -- Auto Plant
    SafeCall(function()
        Tabs.Main:CreateToggle({
            Name = "Auto Plant",
            CurrentValue = false,
            Flag = "AutoPlant",
            Callback = function(value)
                ScriptData.Config.Main.AutoPlant = value
                if value then
                    Notify("Auto Plant", "Enabled", 2)
                    CreateLoop("AutoPlant", function()
                        for _, plot in ipairs(FindPlayerPlots()) do
                            if plot and plot.Parent then
                                local isEmpty = plot:FindFirstChild("Empty") or plot:FindFirstChild("Available")
                                local hasPlant = FindFirstDescendant(plot, "plant", "Model")
                                if (isEmpty and isEmpty.Value == true) or (not hasPlant) then
                                    FireRemote("PlantSeed", plot, ScriptData.Config.Main.SelectedSeed)
                                    FireRemote("Plant", plot, ScriptData.Config.Main.SelectedSeed)
                                end
                            end
                        end
                    end, 0.5)
                else
                    Notify("Auto Plant", "Disabled", 2)
                    StopLoop("AutoPlant")
                end
            end
        })
    end)

    -- Auto Water
    SafeCall(function()
        Tabs.Main:CreateToggle({
            Name = "Auto Water",
            CurrentValue = false,
            Flag = "AutoWater",
            Callback = function(value)
                ScriptData.Config.Main.AutoWater = value
                if value then
                    Notify("Auto Water", "Enabled", 2)
                    CreateLoop("AutoWater", function()
                        for _, plant in ipairs(FindPlants()) do
                            if plant and plant.Parent then
                                FireRemote("WaterPlant", plant)
                                FireRemote("Water", plant)
                                FireRemote("water", plant)
                            end
                        end
                    end, 0.5)
                else
                    Notify("Auto Water", "Disabled", 2)
                    StopLoop("AutoWater")
                end
            end
        })
    end)

    -- Auto Fertilize
    SafeCall(function()
        Tabs.Main:CreateToggle({
            Name = "Auto Fertilize",
            CurrentValue = false,
            Flag = "AutoFertilize",
            Callback = function(value)
                ScriptData.Config.Main.AutoFertilize = value
                if value then
                    Notify("Auto Fertilize", "Enabled", 2)
                    CreateLoop("AutoFertilize", function()
                        for _, plant in ipairs(FindPlants()) do
                            if plant and plant.Parent then
                                FireRemote("FertilizePlant", plant)
                                FireRemote("Fertilize", plant)
                            end
                        end
                    end, 1)
                else
                    Notify("Auto Fertilize", "Disabled", 2)
                    StopLoop("AutoFertilize")
                end
            end
        })
    end)

    SafeCall(function() Tabs.Main:CreateSection("Shop & Economy") end)

    -- Seed/Gear Input
    SafeCall(function()
        Tabs.Main:CreateInput({
            Name = "Seed Name",
            PlaceholderText = "e.g. Carrot",
            RemoveTextAfterFocusLost = false,
            Callback = function(value)
                if value and value ~= "" then
                    ScriptData.Config.Main.SelectedSeed = value
                end
            end
        })
    end)

    SafeCall(function()
        Tabs.Main:CreateInput({
            Name = "Gear Name",
            PlaceholderText = "e.g. Basic Watering Can",
            RemoveTextAfterFocusLost = false,
            Callback = function(value)
                if value and value ~= "" then
                    ScriptData.Config.Main.SelectedGear = value
                end
            end
        })
    end)

    -- Auto Sell
    SafeCall(function()
        Tabs.Main:CreateToggle({
            Name = "Auto Sell",
            CurrentValue = false,
            Flag = "AutoSell",
            Callback = function(value)
                ScriptData.Config.Main.AutoSell = value
                if value then
                    Notify("Auto Sell", "Enabled", 2)
                    CreateLoop("AutoSell", function()
                        FireRemote("SellProduce")
                        FireRemote("Sell")
                        FireRemote("sell")
                        if GameCache.SellArea then
                            local root = GetRootPart()
                            if root then
                                local oldPos = root.CFrame
                                root.CFrame = GameCache.SellArea.CFrame + Vector3.new(0, 3, 0)
                                task.wait(0.2)
                                root.CFrame = oldPos
                            end
                        end
                    end, 2)
                else
                    Notify("Auto Sell", "Disabled", 2)
                    StopLoop("AutoSell")
                end
            end
        })
    end)

    -- Auto Buy Seeds
    SafeCall(function()
        Tabs.Main:CreateToggle({
            Name = "Auto Buy Seeds",
            CurrentValue = false,
            Flag = "AutoBuySeeds",
            Callback = function(value)
                ScriptData.Config.Main.AutoBuySeeds = value
                if value then
                    Notify("Auto Buy Seeds", "Enabled", 2)
                    CreateLoop("AutoBuySeeds", function()
                        FireRemote("BuySeed", ScriptData.Config.Main.SelectedSeed)
                        FireRemote("PurchaseSeed", ScriptData.Config.Main.SelectedSeed)
                    end, 3)
                else
                    Notify("Auto Buy Seeds", "Disabled", 2)
                    StopLoop("AutoBuySeeds")
                end
            end
        })
    end)

    -- Auto Buy Gear
    SafeCall(function()
        Tabs.Main:CreateToggle({
            Name = "Auto Buy Gear",
            CurrentValue = false,
            Flag = "AutoBuyGear",
            Callback = function(value)
                ScriptData.Config.Main.AutoBuyGear = value
                if value then
                    Notify("Auto Buy Gear", "Enabled", 2)
                    CreateLoop("AutoBuyGear", function()
                        FireRemote("BuyGear", ScriptData.Config.Main.SelectedGear)
                        FireRemote("PurchaseGear", ScriptData.Config.Main.SelectedGear)
                    end, 3)
                else
                    Notify("Auto Buy Gear", "Disabled", 2)
                    StopLoop("AutoBuyGear")
                end
            end
        })
    end)

    SafeCall(function() Tabs.Main:CreateSection("Automation") end)

    -- Auto Collect Drops
    SafeCall(function()
        Tabs.Main:CreateToggle({
            Name = "Auto Collect Drops",
            CurrentValue = false,
            Flag = "AutoCollectDrops",
            Callback = function(value)
                ScriptData.Config.Main.AutoCollectDrops = value
                if value then
                    Notify("Auto Collect", "Enabled", 2)
                    CreateLoop("AutoCollectDrops", function()
                        local root = GetRootPart()
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
            end
        })
    end)

    -- Auto Quest
    SafeCall(function()
        Tabs.Main:CreateToggle({
            Name = "Auto Quest",
            CurrentValue = false,
            Flag = "AutoQuest",
            Callback = function(value)
                ScriptData.Config.Main.AutoQuest = value
                if value then
                    Notify("Auto Quest", "Enabled", 2)
                    CreateLoop("AutoQuest", function()
                        FireRemote("AcceptQuest")
                        FireRemote("Quest")
                        FireRemote("CompleteQuest")
                    end, 2)
                else
                    Notify("Auto Quest", "Disabled", 2)
                    StopLoop("AutoQuest")
                end
            end
        })
    end)

    -- Auto Upgrade
    SafeCall(function()
        Tabs.Main:CreateToggle({
            Name = "Auto Upgrade",
            CurrentValue = false,
            Flag = "AutoUpgrade",
            Callback = function(value)
                ScriptData.Config.Main.AutoUpgrade = value
                if value then
                    Notify("Auto Upgrade", "Enabled", 2)
                    CreateLoop("AutoUpgrade", function()
                        FireRemote("Upgrade")
                        FireRemote("upgrade")
                    end, 3)
                else
                    Notify("Auto Upgrade", "Disabled", 2)
                    StopLoop("AutoUpgrade")
                end
            end
        })
    end)

    -- Auto Rebirth
    SafeCall(function()
        Tabs.Main:CreateToggle({
            Name = "Auto Rebirth",
            CurrentValue = false,
            Flag = "AutoRebirth",
            Callback = function(value)
                ScriptData.Config.Main.AutoRebirth = value
                if value then
                    Notify("Auto Rebirth", "Enabled", 2)
                    CreateLoop("AutoRebirth", function()
                        FireRemote("Rebirth")
                        FireRemote("rebirth")
                    end, 5)
                else
                    Notify("Auto Rebirth", "Disabled", 2)
                    StopLoop("AutoRebirth")
                end
            end
        })
    end)

    -- Auto Claim Rewards
    SafeCall(function()
        Tabs.Main:CreateToggle({
            Name = "Auto Claim Rewards",
            CurrentValue = false,
            Flag = "AutoClaimRewards",
            Callback = function(value)
                ScriptData.Config.Main.AutoClaimRewards = value
                if value then
                    Notify("Auto Claim", "Enabled", 2)
                    CreateLoop("AutoClaimRewards", function()
                        FireRemote("ClaimReward")
                        FireRemote("Claim")
                        FireRemote("ClaimDaily")
                    end, 2)
                else
                    Notify("Auto Claim", "Disabled", 2)
                    StopLoop("AutoClaimRewards")
                end
            end
        })
    end)

    -- Auto Event
    SafeCall(function()
        Tabs.Main:CreateToggle({
            Name = "Auto Event",
            CurrentValue = false,
            Flag = "AutoEvent",
            Callback = function(value)
                ScriptData.Config.Main.AutoEvent = value
                if value then
                    Notify("Auto Event", "Enabled", 2)
                    CreateLoop("AutoEvent", function()
                        FireRemote("JoinEvent")
                        FireRemote("Event")
                    end, 2)
                else
                    Notify("Auto Event", "Disabled", 2)
                    StopLoop("AutoEvent")
                end
            end
        })
    end)

    -- Auto Gift
    SafeCall(function()
        Tabs.Main:CreateToggle({
            Name = "Auto Gift",
            CurrentValue = false,
            Flag = "AutoGift",
            Callback = function(value)
                ScriptData.Config.Main.AutoGift = value
                if value then
                    Notify("Auto Gift", "Enabled", 2)
                    CreateLoop("AutoGift", function()
                        for _, gift in ipairs(FindAllDescendants(workspace, "gift", "Model")) do
                            if gift and gift.Parent then
                                FireRemote("OpenGift", gift)
                                FireRemote("ClaimGift", gift)
                            end
                        end
                    end, 1)
                else
                    Notify("Auto Gift", "Disabled", 2)
                    StopLoop("AutoGift")
                end
            end
        })
    end)
end

-- ======================
-- PLAYER TAB FEATURES
-- ======================
if Tabs.Player then
    SafeCall(function() Tabs.Player:CreateSection("Movement") end)

    -- WalkSpeed
    SafeCall(function()
        Tabs.Player:CreateSlider({
            Name = "WalkSpeed",
            Range = {16, 200},
            Increment = 1,
            Suffix = "Speed",
            CurrentValue = 16,
            Flag = "WalkSpeed",
            Callback = function(value)
                ScriptData.Config.Player.WalkSpeed = value
                local h = GetHumanoid()
                if h then h.WalkSpeed = value end
            end
        })
    end)

    -- JumpPower
    SafeCall(function()
        Tabs.Player:CreateSlider({
            Name = "JumpPower",
            Range = {50, 300},
            Increment = 1,
            Suffix = "Power",
            CurrentValue = 50,
            Flag = "JumpPower",
            Callback = function(value)
                ScriptData.Config.Player.JumpPower = value
                local h = GetHumanoid()
                if h then
                    h.JumpPower = value
                    h.UseJumpPower = true
                end
            end
        })
    end)

    -- Gravity
    SafeCall(function()
        Tabs.Player:CreateSlider({
            Name = "Gravity",
            Range = {0, 196},
            Increment = 1,
            Suffix = "",
            CurrentValue = 196,
            Flag = "Gravity",
            Callback = function(value)
                ScriptData.Config.Player.Gravity = value
                workspace.Gravity = value
            end
        })
    end)

    SafeCall(function() Tabs.Player:CreateSection("Flight") end)

    -- Fly
    SafeCall(function()
        Tabs.Player:CreateToggle({
            Name = "Fly",
            CurrentValue = false,
            Flag = "Fly",
            Callback = function(value)
                ScriptData.Config.Player.Fly = value
                if value then
                    Notify("Fly", "WASD + Space/Shift to control", 3)
                    CreateLoop("Fly", function()
                        local root = GetRootPart()
                        local humanoid = GetHumanoid()
                        if root and humanoid then
                            local bv = root:FindFirstChild("X0D_FlyVelocity")
                            if not bv then
                                bv = Instance.new("BodyVelocity")
                                bv.Name = "X0D_FlyVelocity"
                                bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                                bv.Parent = root
                            end
                            local moveDir = humanoid.MoveDirection
                            local velocity = Vector3.new(0, 0, 0)
                            local speed = ScriptData.Config.Player.FlySpeed
                            if moveDir.Magnitude > 0 then
                                velocity = velocity + (moveDir * speed)
                            end
                            if Services.UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                                velocity = velocity + Vector3.new(0, speed, 0)
                            end
                            if Services.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                                velocity = velocity - Vector3.new(0, speed, 0)
                            end
                            bv.Velocity = velocity
                        else
                            StopLoop("Fly")
                        end
                    end, 0.01)
                else
                    Notify("Fly", "Disabled", 2)
                    StopLoop("Fly")
                    local root = GetRootPart()
                    if root then
                        local bv = root:FindFirstChild("X0D_FlyVelocity")
                        if bv then bv:Destroy() end
                    end
                end
            end
        })
    end)

    -- Fly Speed
    SafeCall(function()
        Tabs.Player:CreateSlider({
            Name = "Fly Speed",
            Range = {10, 300},
            Increment = 1,
            Suffix = "Speed",
            CurrentValue = 50,
            Flag = "FlySpeed",
            Callback = function(value)
                ScriptData.Config.Player.FlySpeed = value
            end
        })
    end)

    SafeCall(function() Tabs.Player:CreateSection("Abilities") end)

    -- NoClip
    SafeCall(function()
        Tabs.Player:CreateToggle({
            Name = "NoClip",
            CurrentValue = false,
            Flag = "NoClip",
            Callback = function(value)
                ScriptData.Config.Player.NoClip = value
                if value then
                    Notify("NoClip", "Enabled", 2)
                    CreateLoop("NoClip", function()
                        local char = GetCharacter()
                        if char then
                            for _, part in ipairs(char:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.CanCollide = false
                                end
                            end
                        end
                    end, 0.1)
                else
                    Notify("NoClip", "Disabled", 2)
                    StopLoop("NoClip")
                    local char = GetCharacter()
                    if char then
                        for _, part in ipairs(char:GetDescendants()) do
                            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                                part.CanCollide = true
                            end
                        end
                    end
                end
            end
        })
    end)

    -- Infinite Jump
    SafeCall(function()
        Tabs.Player:CreateToggle({
            Name = "Infinite Jump",
            CurrentValue = false,
            Flag = "InfiniteJump",
            Callback = function(value)
                ScriptData.Config.Player.InfiniteJump = value
                if value then
                    Notify("Infinite Jump", "Enabled", 2)
                    AddConnection("InfiniteJump", Services.UserInputService.JumpRequest:Connect(function()
                        local h = GetHumanoid()
                        if h and ScriptData.Config.Player.InfiniteJump then
                            h:ChangeState(Enum.HumanoidStateType.Jumping)
                        end
                    end))
                else
                    Notify("Infinite Jump", "Disabled", 2)
                    RemoveConnection("InfiniteJump")
                end
            end
        })
    end)

    -- Anti AFK
    SafeCall(function()
        Tabs.Player:CreateToggle({
            Name = "Anti AFK",
            CurrentValue = false,
            Flag = "AntiAFK",
            Callback = function(value)
                ScriptData.Config.Player.AntiAFK = value
                if value then
                    Notify("Anti AFK", "Enabled", 2)
                    AddConnection("AntiAFK", LocalPlayer.Idled:Connect(function()
                        Services.VirtualUser:CaptureController()
                        Services.VirtualUser:ClickButton2(Vector2.new())
                    end))
                else
                    Notify("Anti AFK", "Disabled", 2)
                    RemoveConnection("AntiAFK")
                end
            end
        })
    end)

    -- Spinbot
    SafeCall(function()
        Tabs.Player:CreateToggle({
            Name = "Spinbot",
            CurrentValue = false,
            Flag = "Spinbot",
            Callback = function(value)
                ScriptData.Config.Player.Spinbot = value
                if value then
                    Notify("Spinbot", "Enabled", 2)
                    local angle = 0
                    CreateLoop("Spinbot", function()
                        local root = GetRootPart()
                        if root then
                            angle = angle + ScriptData.Config.Player.SpinbotSpeed
                            if angle >= 360 then angle = 0 end
                            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(ScriptData.Config.Player.SpinbotSpeed), 0)
                        end
                    end, 0.01)
                else
                    Notify("Spinbot", "Disabled", 2)
                    StopLoop("Spinbot")
                end
            end
        })
    end)

    -- Spinbot Speed
    SafeCall(function()
        Tabs.Player:CreateSlider({
            Name = "Spinbot Speed",
            Range = {1, 50},
            Increment = 1,
            Suffix = "",
            CurrentValue = 10,
            Flag = "SpinbotSpeed",
            Callback = function(value)
                ScriptData.Config.Player.SpinbotSpeed = value
            end
        })
    end)

    -- Safe Reset
    SafeCall(function()
        Tabs.Player:CreateButton({
            Name = "Safe Reset",
            Callback = function()
                local h = GetHumanoid()
                if h then
                    h.Health = 0
                    Notify("Reset", "Character reset", 2)
                end
            end
        })
    end)
end

-- ======================
-- TELEPORT TAB FEATURES
-- ======================
if Tabs.Teleport then
    SafeCall(function() Tabs.Teleport:CreateSection("Locations") end)

    -- Teleport to Shop
    SafeCall(function()
        Tabs.Teleport:CreateButton({
            Name = "Teleport to Shop",
            Callback = function()
                UpdateGameCache()
                task.wait(0.1)
                if GameCache.Shop then
                    local part = GameCache.Shop:FindFirstChild("HumanoidRootPart") or GameCache.Shop:FindFirstChildWhichIsA("BasePart")
                    if part then
                        TeleportTo(part.Position + Vector3.new(0, 5, 0))
                        Notify("Teleport", "Teleported to Shop", 2)
                    else
                        Notify("Error", "Shop has no parts", 3)
                    end
                else
                    Notify("Error", "Shop not found", 3)
                end
            end
        })
    end)

    -- Teleport to Garden
    SafeCall(function()
        Tabs.Teleport:CreateButton({
            Name = "Teleport to Garden",
            Callback = function()
                UpdateGameCache()
                task.wait(0.1)
                if GameCache.Garden then
                    local part = GameCache.Garden:FindFirstChild("HumanoidRootPart") or GameCache.Garden:FindFirstChildWhichIsA("BasePart")
                    if part then
                        TeleportTo(part.Position + Vector3.new(0, 5, 0))
                        Notify("Teleport", "Teleported to Garden", 2)
                    else
                        Notify("Error", "Garden has no parts", 3)
                    end
                else
                    Notify("Error", "Garden not found", 3)
                end
            end
        })
    end)

    -- Teleport to Spawn
    SafeCall(function()
        Tabs.Teleport:CreateButton({
            Name = "Teleport to Spawn",
            Callback = function()
                UpdateGameCache()
                task.wait(0.1)
                if GameCache.Spawn then
                    TeleportTo(GameCache.Spawn.Position + Vector3.new(0, 5, 0))
                    Notify("Teleport", "Teleported to Spawn", 2)
                else
                    Notify("Error", "Spawn not found", 3)
                end
            end
        })
    end)

    -- Teleport to NPCs
    SafeCall(function()
        Tabs.Teleport:CreateButton({
            Name = "Teleport to NPCs",
            Callback = function()
                UpdateGameCache()
                task.wait(0.1)
                if #GameCache.NPCs > 0 then
                    local npc = GameCache.NPCs[1]
                    local part = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
                    if part then
                        TeleportTo(part.Position + Vector3.new(5, 0, 0))
                        Notify("Teleport", "Teleported to NPC", 2)
                    end
                else
                    Notify("Error", "No NPCs found", 3)
                end
            end
        })
    end)

    -- Teleport to Events
    SafeCall(function()
        Tabs.Teleport:CreateButton({
            Name = "Teleport to Events",
            Callback = function()
                local events = FindAllDescendants(workspace, "event", "Model")
                if #events > 0 then
                    local part = events[1]:FindFirstChildWhichIsA("BasePart")
                    if part then
                        TeleportTo(part.Position + Vector3.new(0, 5, 0))
                        Notify("Teleport", "Teleported to Event", 2)
                    end
                else
                    Notify("Error", "No events found", 3)
                end
            end
        })
    end)

    SafeCall(function() Tabs.Teleport:CreateSection("Players") end)

    local selectedPlayerName = ""

    -- Player Name Input
    SafeCall(function()
        Tabs.Teleport:CreateInput({
            Name = "Player Name",
            PlaceholderText = "Type exact player name",
            RemoveTextAfterFocusLost = false,
            Callback = function(value)
                selectedPlayerName = value
            end
        })
    end)

    -- Player Dropdown
    SafeCall(function()
        local names = {}
        for _, p in ipairs(Services.Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(names, p.Name) end
        end
        if #names == 0 then table.insert(names, "No players") end
        Tabs.Teleport:CreateDropdown({
            Name = "Or Select Player",
            Options = names,
            CurrentOption = names[1],
            Flag = "SelectedPlayerDropdown",
            Callback = function(option)
                selectedPlayerName = option
            end
        })
    end)

    -- Teleport to Player
    SafeCall(function()
        Tabs.Teleport:CreateButton({
            Name = "Teleport to Player",
            Callback = function()
                if selectedPlayerName == "" then
                    Notify("Error", "Type or select a player first", 3)
                    return
                end
                local target = nil
                for _, p in ipairs(Services.Players:GetPlayers()) do
                    if p.Name:lower() == selectedPlayerName:lower() or p.DisplayName:lower() == selectedPlayerName:lower() then
                        target = p
                        break
                    end
                end
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    TeleportTo(target.Character.HumanoidRootPart.Position + Vector3.new(5, 0, 0))
                    Notify("Success", "Teleported to " .. target.Name, 2)
                else
                    Notify("Error", "Player not found or not loaded", 3)
                end
            end
        })
    end)

    -- Refresh Player List
    SafeCall(function()
        Tabs.Teleport:CreateButton({
            Name = "Refresh Player List",
            Callback = function()
                Notify("Info", "Retype player name or rejoin to refresh", 3)
            end
        })
    end)
end

-- ======================
-- VISUAL TAB FEATURES
-- ======================
if Tabs.Visual then
    SafeCall(function() Tabs.Visual:CreateSection("ESP") end)

    -- Player ESP
    SafeCall(function()
        Tabs.Visual:CreateToggle({
            Name = "Player ESP",
            CurrentValue = false,
            Flag = "PlayerESP",
            Callback = function(value)
                ScriptData.Config.Visual.PlayerESP = value
                if value then
                    Notify("Player ESP", "Enabled", 2)
                    CreateLoop("PlayerESP", function()
                        for _, p in ipairs(Services.Players:GetPlayers()) do
                            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                                if not ScriptData.ESPObjects[tostring(p.Character)] then
                                    CreateESP(p.Character, p.Name, Color3.fromRGB(255, 50, 50))
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
            end
        })
    end)

    -- Seed ESP
    SafeCall(function()
        Tabs.Visual:CreateToggle({
            Name = "Seed ESP",
            CurrentValue = false,
            Flag = "SeedESP",
            Callback = function(value)
                ScriptData.Config.Visual.SeedESP = value
                if value then
                    Notify("Seed ESP", "Enabled", 2)
                    CreateLoop("SeedESP", function()
                        for _, s in ipairs(FindAllDescendants(workspace, "seed", "Model")) do
                            if s and s.Parent and not ScriptData.ESPObjects[tostring(s)] then
                                CreateESP(s, "Seed", Color3.fromRGB(50, 255, 50))
                            end
                        end
                    end, 1)
                else
                    Notify("Seed ESP", "Disabled", 2)
                    StopLoop("SeedESP")
                end
            end
        })
    end)

    -- Fruit ESP
    SafeCall(function()
        Tabs.Visual:CreateToggle({
            Name = "Fruit ESP",
            CurrentValue = false,
            Flag = "FruitESP",
            Callback = function(value)
                ScriptData.Config.Visual.FruitESP = value
                if value then
                    Notify("Fruit ESP", "Enabled", 2)
                    CreateLoop("FruitESP", function()
                        for _, f in ipairs(FindAllDescendants(workspace, "fruit", "Model")) do
                            if f and f.Parent and not ScriptData.ESPObjects[tostring(f)] then
                                CreateESP(f, "Fruit", Color3.fromRGB(255, 165, 0))
                            end
                        end
                    end, 1)
                else
                    Notify("Fruit ESP", "Disabled", 2)
                    StopLoop("FruitESP")
                end
            end
        })
    end)

    -- Item ESP
    SafeCall(function()
        Tabs.Visual:CreateToggle({
            Name = "Item ESP",
            CurrentValue = false,
            Flag = "ItemESP",
            Callback = function(value)
                ScriptData.Config.Visual.ItemESP = value
                if value then
                    Notify("Item ESP", "Enabled", 2)
                    CreateLoop("ItemESP", function()
                        for _, i in ipairs(FindAllDescendants(workspace, "item", "Model")) do
                            if i and i.Parent and not ScriptData.ESPObjects[tostring(i)] then
