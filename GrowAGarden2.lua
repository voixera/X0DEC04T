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
    CoreGui = game:GetService("CoreGui")
}

local LocalPlayer = Services.Players.LocalPlayer

local Rayfield
do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
    end)
    if ok and result then
        Rayfield = result
    else
        local ok2, result2 = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Rayfield/main/source"))()
        end)
        if ok2 and result2 then
            Rayfield = result2
        end
    end
end

if not Rayfield then
    error("[X0DEC04T Hub] Failed to load Rayfield UI library. Check your internet connection.")
end

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
        Settings = {
            AutoSave = false
        }
    }
}

local GameCache = {
    Garden = nil, Shop = nil, NPCs = {}, Spawn = nil,
    Plants = {}, Drops = {}, Remotes = {}, PlayerList = {},
    Plots = {}, SellArea = nil
}

local function SafeCall(fn)
    local ok, err = pcall(fn)
    if not ok then
        warn("[X0DEC04T UI Error]: " .. tostring(err))
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

local function GetCharacter() return LocalPlayer.Character end
local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end
local function GetRootPart()
    local char = GetCharacter()
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

local function FindFirstDescendant(parent, name, className)
    if not parent then return nil end
    for _, d in ipairs(parent:GetDescendants()) do
        local nameMatch = not name or d.Name:lower():find(name:lower())
        local classMatch = not className or d:IsA(className)
        if nameMatch and classMatch then return d end
    end
    return nil
end

local function FindAllDescendants(parent, name, className)
    local results = {}
    if not parent then return results end
    for _, d in ipairs(parent:GetDescendants()) do
        local nameMatch = not name or d.Name:lower():find(name:lower())
        local classMatch = not className or d:IsA(className)
        if nameMatch and classMatch then table.insert(results, d) end
    end
    return results
end

local function GetRemote(name, className)
    if GameCache.Remotes[name] then return GameCache.Remotes[name] end
    local remote = FindFirstDescendant(Services.ReplicatedStorage, name, className)
    if not remote then remote = FindFirstDescendant(workspace, name, className) end
    if remote then GameCache.Remotes[name] = remote end
    return remote
end

local function FireRemote(remoteName, ...)
    local remote = GetRemote(remoteName, "RemoteEvent") or GetRemote(remoteName, "RemoteFunction")
    if remote then
        pcall(function()
            if remote:IsA("RemoteEvent") then remote:FireServer(...)
            elseif remote:IsA("RemoteFunction") then remote:InvokeServer(...) end
        end)
        return true
    end
    return false
end

local function TeleportTo(position)
    local root = GetRootPart()
    if root then root.CFrame = CFrame.new(position) end
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
        GameCache.Garden = workspace:FindFirstChild("Garden") or workspace:FindFirstChild("PlayerGarden") or workspace:FindFirstChild("PlayerPlots") or workspace:FindFirstChild(LocalPlayer.Name)
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
    billboard.Name = "ESP_" .. text
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
    if targetPart:IsA("BasePart") then
        local highlight = Instance.new("Highlight")
        highlight.FillColor = color or Color3.fromRGB(255, 255, 255)
        highlight.OutlineColor = color or Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.5
        highlight.Parent = object
        ScriptData.ESPObjects[key .. "_hl"] = highlight
    end
end

local function RemoveESP(object)
    local key = tostring(object)
    if ScriptData.ESPObjects[key] then pcall(function() ScriptData.ESPObjects[key]:Destroy() end) ScriptData.ESPObjects[key] = nil end
    if ScriptData.ESPObjects[key .. "_hl"] then pcall(function() ScriptData.ESPObjects[key .. "_hl"]:Destroy() end) ScriptData.ESPObjects[key .. "_hl"] = nil end
end

local function ClearAllESP()
    for _, esp in pairs(ScriptData.ESPObjects) do pcall(function() esp:Destroy() end) end
    ScriptData.ESPObjects = {}
end

local function SaveConfigProfile(profileName)
    profileName = profileName or "default"
    local fileName = "X0DEC04T_GAG2_" .. profileName .. ".json"
    local ok, result = pcall(function() return Services.HttpService:JSONEncode(ScriptData.Config) end)
    if ok and writefile then writefile(fileName, result) return true end
    return false
end

local function LoadConfigProfile(profileName)
    profileName = profileName or "default"
    local fileName = "X0DEC04T_GAG2_" .. profileName .. ".json"
    if isfile and isfile(fileName) and readfile then
        local ok, result = pcall(function() return Services.HttpService:JSONDecode(readfile(fileName)) end)
        if ok and result then
            for cat, settings in pairs(result) do
                if ScriptData.Config[cat] then
                    for k, v in pairs(settings) do ScriptData.Config[cat][k] = v end
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

UpdateGameCache()

local Window
SafeCall(function()
    Window = Rayfield:CreateWindow({
        Name = "X0DEC04T Hub | Grow a Garden 2",
        LoadingTitle = "X0DEC04T Hub",
        LoadingSubtitle = "Loading Grow a Garden 2 features...",
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "X0DEC04THub",
            FileName = "GrowAGarden2Config"
        },
        KeySystem = false
    })
end)

if not Window then
    error("[X0DEC04T Hub] Failed to create Rayfield window.")
end

local MainTab, PlayerTab, TeleportTab, VisualTab, MiscTab, SettingsTab, CreditsTab

SafeCall(function() MainTab = Window:CreateTab("Main", 4483362458) end)
SafeCall(function() PlayerTab = Window:CreateTab("Player", 4483362458) end)
SafeCall(function() TeleportTab = Window:CreateTab("Teleport", 4483362458) end)
SafeCall(function() VisualTab = Window:CreateTab("Visual", 4483362458) end)
SafeCall(function() MiscTab = Window:CreateTab("Misc", 4483362458) end)
SafeCall(function() SettingsTab = Window:CreateTab("Settings", 4483362458) end)
SafeCall(function() CreditsTab = Window:CreateTab("Credits", 4483362458) end)

if MainTab then
    SafeCall(function() MainTab:CreateSection("Farming Features") end)

    SafeCall(function()
        MainTab:CreateToggle({
            Name = "Auto Harvest",
            CurrentValue = false,
            Flag = "AutoHarvest",
            Callback = function(value)
                ScriptData.Config.Main.AutoHarvest = value
                if value then
                    Notify("Auto Harvest", "Enabled", 2)
                    CreateLoop("AutoHarvest", function()
                        UpdateGameCache()
                        for _, plant in ipairs(FindPlants()) do
                            if plant then
                                local ready = plant:FindFirstChild("Ready") or plant:FindFirstChild("Harvestable") or plant:FindFirstChild("Grown")
                                if ready and ready.Value == true then
                                    local cd = FindFirstDescendant(plant, nil, "ClickDetector")
                                    if cd then fireclickdetector(cd) end
                                    local pp = FindFirstDescendant(plant, nil, "ProximityPrompt")
                                    if pp then fireproximityprompt(pp) end
                                    FireRemote("HarvestPlant", plant)
                                    FireRemote("Harvest", plant)
                                    FireRemote("harvest", plant)
                                end
                            end
                        end
                    end, 0.3)
                else
                    Notify("Auto Harvest", "Disabled", 2)
                    StopLoop("AutoHarvest")
                end
            end
        })
    end)

    SafeCall(function()
        MainTab:CreateToggle({
            Name = "Auto Plant",
            CurrentValue = false,
            Flag = "AutoPlant",
            Callback = function(value)
                ScriptData.Config.Main.AutoPlant = value
                if value then
                    Notify("Auto Plant", "Enabled", 2)
                    CreateLoop("AutoPlant", function()
                        UpdateGameCache()
                        for _, plot in ipairs(GameCache.Plots) do
                            if plot then
                                local isEmpty = plot:FindFirstChild("Empty") or plot:FindFirstChild("Available")
                                local hasPlant = FindFirstDescendant(plot, "plant", "Model")
                                if (isEmpty and isEmpty.Value == true) or (not hasPlant) then
                                    local cd = FindFirstDescendant(plot, nil, "ClickDetector")
                                    if cd then fireclickdetector(cd) end
                                    local pp = FindFirstDescendant(plot, nil, "ProximityPrompt")
                                    if pp then fireproximityprompt(pp) end
                                    FireRemote("PlantSeed", plot, ScriptData.Config.Main.SelectedSeed)
                                    FireRemote("Plant", plot, ScriptData.Config.Main.SelectedSeed)
                                    FireRemote("plant", plot)
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

    SafeCall(function()
        MainTab:CreateToggle({
            Name = "Auto Water",
            CurrentValue = false,
            Flag = "AutoWater",
            Callback = function(value)
                ScriptData.Config.Main.AutoWater = value
                if value then
                    Notify("Auto Water", "Enabled", 2)
                    CreateLoop("AutoWater", function()
                        for _, plant in ipairs(FindPlants()) do
                            if plant then
                                local needsWater = plant:FindFirstChild("NeedsWater") or plant:FindFirstChild("Watered")
                                if (needsWater and needsWater.Value == true) or not needsWater then
                                    local cd = FindFirstDescendant(plant, nil, "ClickDetector")
                                    if cd then fireclickdetector(cd) end
                                    local pp = FindFirstDescendant(plant, nil, "ProximityPrompt")
                                    if pp then fireproximityprompt(pp) end
                                    FireRemote("WaterPlant", plant)
                                    FireRemote("Water", plant)
                                    FireRemote("water", plant)
                                end
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

    SafeCall(function()
        MainTab:CreateToggle({
            Name = "Auto Fertilize",
            CurrentValue = false,
            Flag = "AutoFertilize",
            Callback = function(value)
                ScriptData.Config.Main.AutoFertilize = value
                if value then
                    Notify("Auto Fertilize", "Enabled", 2)
                    CreateLoop("AutoFertilize", function()
                        for _, plant in ipairs(FindPlants()) do
                            if plant then
                                FireRemote("FertilizePlant", plant)
                                FireRemote("Fertilize", plant)
                                FireRemote("fertilize", plant)
                                FireRemote("UseFertilizer", plant)
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

    SafeCall(function() MainTab:CreateSection("Shop & Economy") end)

    SafeCall(function()
        MainTab:CreateInput({
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
        MainTab:CreateInput({
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

    SafeCall(function()
        MainTab:CreateToggle({
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
                        FireRemote("SellItems")
                        if GameCache.SellArea and GameCache.SellArea:IsA("BasePart") then
                            local root = GetRootPart()
                            if root then
                                local oldPos = root.CFrame
                                root.CFrame = GameCache.SellArea.CFrame
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

    SafeCall(function()
        MainTab:CreateToggle({
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
                        FireRemote("buy", "seed", ScriptData.Config.Main.SelectedSeed)
                    end, 3)
                else
                    Notify("Auto Buy Seeds", "Disabled", 2)
                    StopLoop("AutoBuySeeds")
                end
            end
        })
    end)

    SafeCall(function()
        MainTab:CreateToggle({
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
                        FireRemote("buy", "gear", ScriptData.Config.Main.SelectedGear)
                    end, 3)
                else
                    Notify("Auto Buy Gear", "Disabled", 2)
                    StopLoop("AutoBuyGear")
                end
            end
        })
    end)

    SafeCall(function() MainTab:CreateSection("Automation") end)

    SafeCall(function()
        MainTab:CreateToggle({
            Name = "Auto Collect Drops",
            CurrentValue = false,
            Flag = "AutoCollectDrops",
            Callback = function(value)
                ScriptData.Config.Main.AutoCollectDrops = value
                if value then
                    Notify("Auto Collect", "Enabled", 2)
                    CreateLoop("AutoCollectDrops", function()
                        UpdateGameCache()
                        local root = GetRootPart()
                        if root then
                            for _, drop in ipairs(GameCache.Drops) do
                                if drop and drop:IsA("BasePart") and drop.Parent then
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

    SafeCall(function()
        MainTab:CreateToggle({
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
                        FireRemote("quest")
                        FireRemote("CompleteQuest")
                        FireRemote("TurnInQuest")
                    end, 2)
                else
                    Notify("Auto Quest", "Disabled", 2)
                    StopLoop("AutoQuest")
                end
            end
        })
    end)

    SafeCall(function()
        MainTab:CreateToggle({
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
                        FireRemote("UpgradeTool")
                        FireRemote("UpgradePlot")
                    end, 3)
                else
                    Notify("Auto Upgrade", "Disabled", 2)
                    StopLoop("AutoUpgrade")
                end
            end
        })
    end)

    SafeCall(function()
        MainTab:CreateToggle({
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
                        FireRemote("Prestige")
                    end, 5)
                else
                    Notify("Auto Rebirth", "Disabled", 2)
                    StopLoop("AutoRebirth")
                end
            end
        })
    end)

    SafeCall(function()
        MainTab:CreateToggle({
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
                        FireRemote("claim")
                        FireRemote("ClaimDaily")
                        FireRemote("ClaimAchievement")
                    end, 2)
                else
                    Notify("Auto Claim", "Disabled", 2)
                    StopLoop("AutoClaimRewards")
                end
            end
        })
    end)

    SafeCall(function()
        MainTab:CreateToggle({
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
                        FireRemote("event")
                    end, 2)
                else
                    Notify("Auto Event", "Disabled", 2)
                    StopLoop("AutoEvent")
                end
            end
        })
    end)

    SafeCall(function()
        MainTab:CreateToggle({
            Name = "Auto Gift",
            CurrentValue = false,
            Flag = "AutoGift",
            Callback = function(value)
                ScriptData.Config.Main.AutoGift = value
                if value then
                    Notify("Auto Gift", "Enabled", 2)
                    CreateLoop("AutoGift", function()
                        for _, gift in ipairs(FindAllDescendants(workspace, "gift", "Model")) do
                            if gift then
                                local cd = FindFirstDescendant(gift, nil, "ClickDetector")
                                if cd then fireclickdetector(cd) end
                                local pp = FindFirstDescendant(gift, nil, "ProximityPrompt")
                                if pp then fireproximityprompt(pp) end
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

if PlayerTab then
    SafeCall(function() PlayerTab:CreateSection("Movement") end)

    SafeCall(function()
        PlayerTab:CreateSlider({
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

    SafeCall(function()
        PlayerTab:CreateSlider({
            Name = "JumpPower",
            Range = {50, 300},
            Increment = 1,
            Suffix = "Power",
            CurrentValue = 50,
            Flag = "JumpPower",
            Callback = function(value)
                ScriptData.Config.Player.JumpPower = value
                local h = GetHumanoid()
                if h then h.JumpPower = value h.UseJumpPower = true end
            end
        })
    end)

    SafeCall(function()
        PlayerTab:CreateSlider({
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

    SafeCall(function() PlayerTab:CreateSection("Flight") end)

    SafeCall(function()
        PlayerTab:CreateToggle({
            Name = "Fly",
            CurrentValue = false,
            Flag = "Fly",
            Callback = function(value)
                ScriptData.Config.Player.Fly = value
                if value then
                    Notify("Fly", "Enabled - WASD + Space/Shift", 3)
                    CreateLoop("Fly", function()
                        local root = GetRootPart()
                        local humanoid = GetHumanoid()
                        if root and humanoid then
                            local bv = root:FindFirstChild("FlyVelocity")
                            if not bv then
                                bv = Instance.new("BodyVelocity")
                                bv.Name = "FlyVelocity"
                                bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                                bv.Parent = root
                            end
                            local moveDir = humanoid.MoveDirection
                            local velocity = Vector3.new(0, 0, 0)
                            local speed = ScriptData.Config.Player.FlySpeed
                            if moveDir.Magnitude > 0 then velocity = velocity + (moveDir * speed) end
                            if Services.UserInputService:IsKeyDown(Enum.KeyCode.Space) then velocity = velocity + Vector3.new(0, speed, 0) end
                            if Services.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then velocity = velocity - Vector3.new(0, speed, 0) end
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
                        local bv = root:FindFirstChild("FlyVelocity")
                        if bv then bv:Destroy() end
                    end
                end
            end
        })
    end)

    SafeCall(function()
        PlayerTab:CreateSlider({
            Name = "Fly Speed",
            Range = {10, 200},
            Increment = 1,
            Suffix = "Speed",
            CurrentValue = 50,
            Flag = "FlySpeed",
            Callback = function(value)
                ScriptData.Config.Player.FlySpeed = value
            end
        })
    end)

    SafeCall(function() PlayerTab:CreateSection("Abilities") end)

    SafeCall(function()
        PlayerTab:CreateToggle({
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
                                if part:IsA("BasePart") then part.CanCollide = false end
                            end
                        end
                    end, 0.1)
                else
                    Notify("NoClip", "Disabled", 2)
                    StopLoop("NoClip")
                    local char = GetCharacter()
                    if char then
                        for _, part in ipairs(char:GetDescendants()) do
                            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then part.CanCollide = true end
                        end
                    end
                end
            end
        })
    end)

    SafeCall(function()
        PlayerTab:CreateToggle({
            Name = "Infinite Jump",
            CurrentValue = false,
            Flag = "InfiniteJump",
            Callback = function(value)
                ScriptData.Config.Player.InfiniteJump = value
                if value then
                    Notify("Infinite Jump", "Enabled", 2)
                    AddConnection("InfiniteJump", Services.UserInputService.JumpRequest:Connect(function()
                        local h = GetHumanoid()
                        if h and ScriptData.Config.Player.InfiniteJump then h:ChangeState(Enum.HumanoidStateType.Jumping) end
                    end))
                else
                    Notify("Infinite Jump", "Disabled", 2)
                    RemoveConnection("InfiniteJump")
                end
            end
        })
    end)

    SafeCall(function()
        PlayerTab:CreateToggle({
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

    SafeCall(function()
        PlayerTab:CreateToggle({
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
                            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(angle), 0)
                        end
                    end, 0.01)
                else
                    Notify("Spinbot", "Disabled", 2)
                    StopLoop("Spinbot")
                end
            end
        })
    end)

    SafeCall(function()
        PlayerTab:CreateSlider({
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

    SafeCall(function()
        PlayerTab:CreateButton({
            Name = "Safe Reset",
            Callback = function()
                local h = GetHumanoid()
                if h then h.Health = 0 Notify("Reset", "Character reset", 2) end
            end
        })
    end)
end

if TeleportTab then
    SafeCall(function() TeleportTab:CreateSection("Locations") end)

    SafeCall(function()
        TeleportTab:CreateButton({
            Name = "Teleport to Shop",
            Callback = function()
                UpdateGameCache()
                if GameCache.Shop then
                    local part = GameCache.Shop:FindFirstChild("HumanoidRootPart") or GameCache.Shop:FindFirstChildWhichIsA("BasePart")
                    if part then TeleportTo(part.Position + Vector3.new(0, 5, 0)) Notify("Teleport", "Teleported to Shop", 2) end
                else
                    Notify("Error", "Shop not found", 3)
                end
            end
        })
    end)

    SafeCall(function()
        TeleportTab:CreateButton({
            Name = "Teleport to Garden",
            Callback = function()
                UpdateGameCache()
                if GameCache.Garden then
                    local part = GameCache.Garden:FindFirstChild("HumanoidRootPart") or GameCache.Garden:FindFirstChildWhichIsA("BasePart")
                    if part then TeleportTo(part.Position + Vector3.new(0, 5, 0)) Notify("Teleport", "Teleported to Garden", 2) end
                else
                    Notify("Error", "Garden not found", 3)
                end
            end
        })
    end)

    SafeCall(function()
        TeleportTab:CreateButton({
            Name = "Teleport to Spawn",
            Callback = function()
                UpdateGameCache()
                if GameCache.Spawn then
                    TeleportTo(GameCache.Spawn.Position + Vector3.new(0, 5, 0))
                    Notify("Teleport", "Teleported to Spawn", 2)
                else
                    Notify("Error", "Spawn not found", 3)
                end
            end
        })
    end)

    SafeCall(function()
        TeleportTab:CreateButton({
            Name = "Teleport to NPCs",
            Callback = function()
                UpdateGameCache()
                if #GameCache.NPCs > 0 then
                    local npc = GameCache.NPCs[1]
                    local part = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
                    if part then TeleportTo(part.Position + Vector3.new(5, 0, 0)) Notify("Teleport", "Teleported to NPC", 2) end
                else
                    Notify("Error", "No NPCs found", 3)
                end
            end
        })
    end)

    SafeCall(function()
        TeleportTab:CreateButton({
            Name = "Teleport to Events",
            Callback = function()
                local events = FindAllDescendants(workspace, "event", "Model")
                if #events > 0 then
                    local part = events[1]:FindFirstChildWhichIsA("BasePart")
                    if part then TeleportTo(part.Position + Vector3.new(0, 5, 0)) Notify("Teleport", "Teleported to Event", 2) end
                else
                    Notify("Error", "No events found", 3)
                end
            end
        })
    end)

    SafeCall(function() TeleportTab:CreateSection("Players") end)

    local selectedPlayerName = ""

    SafeCall(function()
        TeleportTab:CreateInput({
            Name = "Player Name",
            PlaceholderText = "Type exact player name",
            RemoveTextAfterFocusLost = false,
            Callback = function(value)
                selectedPlayerName = value
            end
        })
    end)

    SafeCall(function()
        local names = {}
        for _, p in ipairs(Services.Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(names, p.Name) end
        end
        if #names == 0 then table.insert(names, "No players") end
        TeleportTab:CreateDropdown({
            Name = "Or Select Player",
            Options = names,
            CurrentOption = {names[1]},
            Flag = "SelectedPlayerDropdown",
            Callback = function(option)
                selectedPlayerName = option[1] or option
            end
        })
    end)

    SafeCall(function()
        TeleportTab:CreateButton({
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
                    Notify("Error", "Player not found", 3)
                end
            end
        })
    end)

    SafeCall(function()
        TeleportTab:CreateButton({
            Name = "Refresh Player List",
            Callback = function()
                Notify("Info", "Re-select or type player name to refresh", 3)
            end
        })
    end)
end

if VisualTab then
    SafeCall(function() VisualTab:CreateSection("ESP") end)

    SafeCall(function()
        VisualTab:CreateToggle({
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
                                    CreateESP(p.Character, p.Name, Color3.fromRGB(255, 0, 0))
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

    SafeCall(function()
        VisualTab:CreateToggle({
            Name = "Seed ESP",
            CurrentValue = false,
            Flag = "SeedESP",
            Callback = function(value)
                ScriptData.Config.Visual.SeedESP = value
                if value then
                    Notify("Seed ESP", "Enabled", 2)
                    CreateLoop("SeedESP", function()
                        for _, s in ipairs(FindAllDescendants(workspace, "seed", "Model")) do
                            if not ScriptData.ESPObjects[tostring(s)] then CreateESP(s, "Seed", Color3.fromRGB(0, 255, 0)) end
                        end
                    end, 1)
                else
                    Notify("Seed ESP", "Disabled", 2)
                    StopLoop("SeedESP")
                end
            end
        })
    end)

    SafeCall(function()
        VisualTab:CreateToggle({
            Name = "Fruit ESP",
            CurrentValue = false,
            Flag = "FruitESP",
            Callback = function(value)
                ScriptData.Config.Visual.FruitESP = value
                if value then
                    Notify("Fruit ESP", "Enabled", 2)
                    CreateLoop("FruitESP", function()
                        for _, f in ipairs(FindAllDescendants(workspace, "fruit", "Model")) do
                            if not ScriptData.ESPObjects[tostring(f)] then CreateESP(f, "Fruit", Color3.fromRGB(255, 165, 0)) end
                        end
                    end, 1)
                else
                    Notify("Fruit ESP", "Disabled", 2)
                    StopLoop("FruitESP")
                end
            end
        })
    end)

    SafeCall(function()
        VisualTab:CreateToggle({
            Name = "Item ESP",
            CurrentValue = false,
            Flag = "ItemESP",
            Callback = function(value)
                ScriptData.Config.Visual.ItemESP = value
                if value then
                    Notify("Item ESP", "Enabled", 2)
                    CreateLoop("ItemESP", function()
                        for _, i in ipairs(FindAllDescendants(workspace, "item", "Model")) do
                            if not ScriptData.ESPObjects[tostring(i)] then CreateESP(i, "Item", Color3.fromRGB(0, 255, 255)) end
                        end
                    end, 1)
                else
                    Notify("Item ESP", "Disabled", 2)
                    StopLoop("ItemESP")
                end
            end
        })
    end)

    SafeCall(function()
        VisualTab:CreateToggle({
            Name = "NPC ESP",
            CurrentValue = false,
            Flag = "NPCESP",
            Callback = function(value)
                ScriptData.Config.Visual.NPCESP = value
                if value then
                    Notify("NPC ESP", "Enabled", 2)
                    CreateLoop("NPCESP", function()
                        UpdateGameCache()
                        for _, n in ipairs(GameCache.NPCs) do
                            if not ScriptData.ESPObjects[tostring(n)] then CreateESP(n, "NPC", Color3.fromRGB(255, 255, 0)) end
                        end
                    end, 1)
                else
                    Notify("NPC ESP", "Disabled", 2)
                    StopLoop("NPCESP")
                end
            end
        })
    end)

    SafeCall(function()
        VisualTab:CreateToggle({
            Name = "Chest ESP",
            CurrentValue = false,
            Flag = "ChestESP",
            Callback = function(value)
                ScriptData.Config.Visual.ChestESP = value
                if value then
                    Notify("Chest ESP", "Enabled", 2)
                    CreateLoop("ChestESP", function()
                        for _, c in ipairs(FindAllDescendants(workspace, "chest", "Model")) do
                            if not ScriptData.ESPObjects[tostring(c)] then CreateESP(c, "Chest", Color3.fromRGB(255, 215, 0)) end
                        end
                    end, 1)
                else
                    Notify("Chest ESP", "Disabled", 2)
                    StopLoop("ChestESP")
                end
            end
        })
    end)

    SafeCall(function() VisualTab:CreateSection("Rendering") end)

    SafeCall(function()
        VisualTab:CreateToggle({
            Name = "Fullbright",
            CurrentValue = false,
            Flag = "Fullbright",
            Callback = function(value)
                ScriptData.Config.Visual.Fullbright = value
                if value then
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
            end
        })
    end)

    SafeCall(function()
        VisualTab:CreateButton({
            Name = "Remove Fog",
            Callback = function()
                Services.Lighting.FogEnd = 100000
                for _, e in ipairs(Services.Lighting:GetChildren()) do
                    if e:IsA("Atmosphere") or e:IsA("BlurEffect") or e:IsA("ColorCorrectionEffect") then e:Destroy() end
                end
                Notify("Success", "Fog removed", 2)
            end
        })
    end)

    SafeCall(function()
        VisualTab:CreateButton({
            Name = "FPS Boost",
            Callback = function()
                local t = workspace.Terrain
                t.WaterWaveSize = 0
                t.WaterWaveSpeed = 0
                t.WaterReflectance = 0
                t.WaterTransparency = 0
                Services.Lighting.GlobalShadows = false
                Services.Lighting.FogEnd = 9e9
                pcall(function() settings().Rendering.QualityLevel = "Level01" end)
                for _, v in pairs(workspace:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.Material = Enum.Material.Plastic
                        v.Reflectance = 0
                    elseif v:IsA("Decal") or v:IsA("Texture") then
                        v.Transparency = 1
                    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
                        v.Enabled = false
                    elseif v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                        v.Enabled = false
                    end
                end
                for _, e in pairs(Services.Lighting:GetChildren()) do
                    if e:IsA("PostEffect") then e.Enabled = false end
                end
                Notify("Success", "FPS Boost applied", 2)
            end
        })
    end)

    SafeCall(function()
        VisualTab:CreateButton({
            Name = "Destroy Effects",
            Callback = function()
                for _, v in pairs(workspace:GetDescendants()) do
                    if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                        v:Destroy()
                    end
                end
                Notify("Success", "Effects destroyed", 2)
            end
        })
    end)
end

if MiscTab then
    SafeCall(function() MiscTab:CreateSection("Server") end)

    SafeCall(function()
        MiscTab:CreateButton({
            Name = "Server Hop",
            Callback = function()
                Notify("Server Hop", "Finding new server...", 3)
                pcall(function()
                    local req = request or http_request or (syn and syn.request)
                    if not req then Notify("Error", "Exploit not supported", 3) return end
                    local response = req({ Url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100", game.PlaceId), Method = "GET" })
                    local body = Services.HttpService:JSONDecode(response.Body)
                    local servers = {}
                    if body and body.data then
                        for _, s in ipairs(body.data) do
                            if s.playing < s.maxPlayers and s.id ~= game.JobId then table.insert(servers, s) end
                        end
                    end
                    if #servers > 0 then
                        local r = servers[math.random(1, #servers)]
                        Services.TeleportService:TeleportToPlaceInstance(game.PlaceId, r.id, LocalPlayer)
                    else
                        Notify("Error", "No servers found", 3)
                    end
                end)
            end
        })
    end)

    SafeCall(function()
        MiscTab:CreateButton({
            Name = "Rejoin",
            Callback = function()
                Services.TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end
        })
    end)

    SafeCall(function()
        MiscTab:CreateButton({
            Name = "Copy JobId",
            Callback = function()
                if setclipboard then setclipboard(game.JobId) Notify("Success", "JobId copied", 2)
                else Notify("Error", "Clipboard not supported", 3) end
            end
        })
    end)

    SafeCall(function()
        MiscTab:CreateButton({
            Name = "Copy PlaceId",
            Callback = function()
                if setclipboard then setclipboard(tostring(game.PlaceId)) Notify("Success", "PlaceId copied", 2)
                else Notify("Error", "Clipboard not supported", 3) end
            end
        })
    end)

    SafeCall(function() MiscTab:CreateSection("Game") end)

    SafeCall(function()
        MiscTab:CreateButton({
            Name = "Destroy UI",
            Callback = function()
                pcall(function() Window:Destroy() end)
            end
        })
    end)
end

if SettingsTab then
    SafeCall(function() SettingsTab:CreateSection("Configuration") end)

    local profileName = "default"

    SafeCall(function()
        SettingsTab:CreateInput({
            Name = "Profile Name",
            PlaceholderText = "Enter profile name",
            RemoveTextAfterFocusLost = false,
            Callback = function(value)
                profileName = value ~= "" and value or "default"
            end
        })
    end)

    SafeCall(function()
        SettingsTab:CreateButton({
            Name = "Save Config",
            Callback = function()
                if SaveConfigProfile(profileName) then Notify("Success", "Config saved: " .. profileName, 2)
                else Notify("Error", "Failed to save config", 3) end
            end
        })
    end)

    SafeCall(function()
        SettingsTab:CreateButton({
            Name = "Load Config",
            Callback = function()
                if LoadConfigProfile(profileName) then Notify("Success", "Config loaded: " .. profileName, 2)
                else Notify("Warning", "No config found: " .. profileName, 3) end
            end
        })
    end)

    SafeCall(function()
        SettingsTab:CreateButton({
            Name = "Delete Config",
            Callback = function()
                local fileName = "X0DEC04T_GAG2_" .. profileName .. ".json"
                if isfile and isfile(fileName) and delfile then
                    delfile(fileName)
                    Notify("Success", "Config deleted: " .. profileName, 2)
                else
                    Notify("Error", "Config not found", 3)
                end
            end
        })
    end)

    SafeCall(function()
        SettingsTab:CreateToggle({
            Name = "Auto Save Config",
            CurrentValue = false,
            Flag = "AutoSaveConfig",
            Callback = function(value)
                ScriptData.Config.Settings.AutoSave = value
                if value then
                    Notify("Auto Save", "Enabled (60s)", 2)
                    CreateLoop("AutoSave", function() SaveConfigProfile(profileName) end, 60)
                else
                    Notify("Auto Save", "Disabled", 2)
                    StopLoop("AutoSave")
                end
            end
        })
    end)

    SafeCall(function() SettingsTab:CreateSection("Keybinds") end)

    SafeCall(function()
        SettingsTab:CreateKeybind({
            Name = "Toggle UI Key",
            CurrentKeybind = "K",
            HoldToInteract = false,
            Flag = "ToggleUIKeybind",
            Callback = function()
            end
        })
    end)
end

if CreditsTab then
    SafeCall(function() CreditsTab:CreateSection("Credits") end)

    SafeCall(function()
        CreditsTab:CreateParagraph({
            Title = "X0DEC04T Hub v1.0.0",
            Content = "Created by X0DEC04T for Grow a Garden 2.\nPowered by Rayfield UI Library."
        })
    end)

    SafeCall(function()
        CreditsTab:CreateButton({
            Name = "Copy Discord Invite",
            Callback = function()
                if setclipboard then setclipboard("discord.gg/x0dec04t") Notify("Success", "Discord link copied", 3)
                else Notify("Info", "discord.gg/x0dec04t", 5) end
            end
        })
    end)
end

AddConnection("CharacterAdded", LocalPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.5)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end
    if ScriptData.Config.Player.WalkSpeed ~= ScriptData.OriginalValues.WalkSpeed then
        humanoid.WalkSpeed = ScriptData.Config.Player.WalkSpeed
    end
    if ScriptData.Config.Player.JumpPower ~= ScriptData.OriginalValues.JumpPower then
        humanoid.JumpPower = ScriptData.Config.Player.JumpPower
        humanoid.UseJumpPower = true
    end
end))

task.spawn(function()
    while task.wait(10) do UpdateGameCache() end
end)

LoadConfigProfile("default")
Notify("X0DEC04T Hub", "Loaded successfully for Grow a Garden 2!", 5)

local function Cleanup()
    for _, connection in pairs(ScriptData.Connections) do pcall(function() connection:Disconnect() end) end
    for name in pairs(ScriptData.Loops) do ScriptData.Loops[name] = false end
    ClearAllESP()
    workspace.Gravity = ScriptData.OriginalValues.Gravity
    Services.Lighting.Brightness = ScriptData.OriginalValues.Brightness
    Services.Lighting.ClockTime = ScriptData.OriginalValues.ClockTime
    Services.Lighting.FogEnd = ScriptData.OriginalValues.FogEnd
    Services.Lighting.GlobalShadows = ScriptData.OriginalValues.GlobalShadows
    local h = GetHumanoid()
    if h then
        h.WalkSpeed = ScriptData.OriginalValues.WalkSpeed
        h.JumpPower = ScriptData.OriginalValues.JumpPower
    end
end

Services.Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then Cleanup() end
end)
