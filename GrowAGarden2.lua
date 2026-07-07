local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/FrostyLabs1/WindUI/main/dist/wind.min.lua"))()

local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    Workspace = game:GetService("Workspace"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    ReplicatedFirst = game:GetService("ReplicatedFirst"),
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
local CurrentCamera = workspace.CurrentCamera

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
            AutoHarvest = false,
            AutoPlant = false,
            AutoWater = false,
            AutoSell = false,
            AutoBuySeeds = false,
            AutoBuyGear = false,
            AutoCollectDrops = false,
            AutoQuest = false,
            AutoUpgrade = false,
            AutoRebirth = false,
            AutoClaimRewards = false,
            AutoEvent = false,
            AutoGift = false,
            AutoFertilize = false,
            SelectedSeed = nil,
            SelectedGear = nil
        },
        Player = {
            WalkSpeed = 16,
            JumpPower = 50,
            Gravity = 196.2,
            Fly = false,
            FlySpeed = 50,
            NoClip = false,
            InfiniteJump = false,
            AntiAFK = false,
            Spinbot = false,
            SpinbotSpeed = 10
        },
        Visual = {
            PlayerESP = false,
            SeedESP = false,
            FruitESP = false,
            ItemESP = false,
            NPCESP = false,
            ChestESP = false,
            Tracers = false,
            Highlight = false,
            Fullbright = false
        },
        Settings = {
            AutoSave = false,
            Watermark = true,
            UIScale = 1,
            Transparency = 0
        }
    }
}

local GameCache = {
    Garden = nil,
    Shop = nil,
    NPCs = {},
    Events = {},
    Spawn = nil,
    Seeds = {},
    Gear = {},
    Plants = {},
    Drops = {},
    Remotes = {},
    PlayerList = {}
}

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
            local success, err = pcall(func)
            if not success then
                warn("Loop Error [" .. name .. "]:", err)
            end
            task.wait(wait_time or 0.1)
        end
    end)
end

local function StopLoop(name)
    ScriptData.Loops[name] = false
end

local function GetCharacter()
    return LocalPlayer.Character
end

local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetRootPart()
    local char = GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function FindFirstDescendant(parent, name, className)
    for _, descendant in ipairs(parent:GetDescendants()) do
        if (not name or descendant.Name:lower():find(name:lower())) and 
           (not className or descendant:IsA(className)) then
            return descendant
        end
    end
    return nil
end

local function FindAllDescendants(parent, name, className)
    local results = {}
    for _, descendant in ipairs(parent:GetDescendants()) do
        if (not name or descendant.Name:lower():find(name:lower())) and 
           (not className or descendant:IsA(className)) then
            table.insert(results, descendant)
        end
    end
    return results
end

local function GetRemote(name, className)
    if not GameCache.Remotes[name] then
        GameCache.Remotes[name] = FindFirstDescendant(Services.ReplicatedStorage, name, className)
    end
    return GameCache.Remotes[name]
end

local function FireRemote(remoteName, ...)
    local remote = GetRemote(remoteName)
    if remote then
        if remote:IsA("RemoteEvent") then
            remote:FireServer(...)
        elseif remote:IsA("RemoteFunction") then
            return remote:InvokeServer(...)
        end
    end
end

local function TweenToPosition(position, speed)
    local root = GetRootPart()
    if not root then return end
    
    local distance = (root.Position - position).Magnitude
    local duration = distance / (speed or 100)
    
    local tween = Services.TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(position)})
    tween:Play()
    return tween
end

local function TeleportTo(position)
    local root = GetRootPart()
    if root then
        root.CFrame = CFrame.new(position)
    end
end

local function UpdateGameCache()
    task.spawn(function()
        GameCache.Garden = FindFirstDescendant(workspace, "garden", "Model") or FindFirstDescendant(workspace, "plot", "Model")
        GameCache.Shop = FindFirstDescendant(workspace, "shop", "Model") or FindFirstDescendant(workspace, "store", "Model")
        GameCache.Spawn = workspace:FindFirstChild("SpawnLocation") or FindFirstDescendant(workspace, "spawn")
        
        GameCache.NPCs = FindAllDescendants(workspace, nil, "Model")
        local npcFiltered = {}
        for _, model in ipairs(GameCache.NPCs) do
            if model:FindFirstChildOfClass("Humanoid") and model.Name:lower():find("npc") or model:FindFirstChild("Head") and not Services.Players:GetPlayerFromCharacter(model) then
                table.insert(npcFiltered, model)
            end
        end
        GameCache.NPCs = npcFiltered
        
        GameCache.Seeds = FindAllDescendants(workspace, "seed", "Model")
        GameCache.Gear = FindAllDescendants(workspace, "gear", "Model")
        GameCache.Plants = FindAllDescendants(workspace, "plant", "Model")
        GameCache.Drops = FindAllDescendants(workspace, "drop", "Part")
    end)
end

local function CreateESP(object, text, color)
    if not object or not object:IsA("BasePart") and not object:IsA("Model") then return end
    
    local key = tostring(object)
    if ScriptData.ESPObjects[key] then return end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.Parent = object:IsA("Model") and object:FindFirstChild("HumanoidRootPart") or object
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = billboard
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.5
    label.Text = text or object.Name
    label.TextScaled = true
    label.Parent = frame
    
    ScriptData.ESPObjects[key] = billboard
    
    if object:IsA("BasePart") then
        local highlight = Instance.new("Highlight")
        highlight.FillColor = color or Color3.fromRGB(255, 255, 255)
        highlight.OutlineColor = color or Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.Parent = object
        ScriptData.ESPObjects[key .. "_highlight"] = highlight
    end
    
    return billboard
end

local function RemoveESP(object)
    local key = tostring(object)
    if ScriptData.ESPObjects[key] then
        pcall(function() ScriptData.ESPObjects[key]:Destroy() end)
        ScriptData.ESPObjects[key] = nil
    end
    if ScriptData.ESPObjects[key .. "_highlight"] then
        pcall(function() ScriptData.ESPObjects[key .. "_highlight"]:Destroy() end)
        ScriptData.ESPObjects[key .. "_highlight"] = nil
    end
end

local function ClearAllESP()
    for _, esp in pairs(ScriptData.ESPObjects) do
        pcall(function() esp:Destroy() end)
    end
    ScriptData.ESPObjects = {}
end

local function SaveConfig(profileName)
    profileName = profileName or "default"
    local fileName = "X0DEC04T_GrowAGarden2_" .. profileName .. ".json"
    
    local success, result = pcall(function()
        return Services.HttpService:JSONEncode(ScriptData.Config)
    end)
    
    if success then
        writefile(fileName, result)
        return true
    end
    return false
end

local function LoadConfig(profileName)
    profileName = profileName or "default"
    local fileName = "X0DEC04T_GrowAGarden2_" .. profileName .. ".json"
    
    if isfile and isfile(fileName) then
        local success, result = pcall(function()
            return Services.HttpService:JSONDecode(readfile(fileName))
        end)
        
        if success then
            for category, settings in pairs(result) do
                if ScriptData.Config[category] then
                    for setting, value in pairs(settings) do
                        ScriptData.Config[category][setting] = value
                    end
                end
            end
            return true
        end
    end
    return false
end

local function Notify(title, message, duration, type_str)
    local notifType = WindUI.NotificationType.Default
    if type_str == "success" then
        notifType = WindUI.NotificationType.Success
    elseif type_str == "error" then
        notifType = WindUI.NotificationType.Error
    elseif type_str == "warning" then
        notifType = WindUI.NotificationType.Warning
    elseif type_str == "info" then
        notifType = WindUI.NotificationType.Info
    end
    
    WindUI.Notify({
        Title = title,
        Content = message,
        Duration = duration or 3,
        Type = notifType
    })
end

UpdateGameCache()

local Window = WindUI:CreateWindow({
    Title = "X0DEC04T Hub",
    Subtitle = "Grow a Garden 2",
    Icon = "rbxassetid://10734950",
    Author = "X0DEC04T",
    Folder = "X0DEC04THub",
    Size = UDim2.fromOffset(580, 460),
    KeySystem = false,
    Transparent = false
})

local MainTab = Window:CreateTab({
    Name = "Main",
    Icon = "rbxassetid://10734950",
    Visible = true
})

local PlayerTab = Window:CreateTab({
    Name = "Player",
    Icon = "rbxassetid://10747372",
    Visible = true
})

local TeleportTab = Window:CreateTab({
    Name = "Teleport",
    Icon = "rbxassetid://10723407",
    Visible = true
})

local VisualTab = Window:CreateTab({
    Name = "Visual",
    Icon = "rbxassetid://10734896",
    Visible = true
})

local MiscTab = Window:CreateTab({
    Name = "Misc",
    Icon = "rbxassetid://10734949",
    Visible = true
})

local SettingsTab = Window:CreateTab({
    Name = "Settings",
    Icon = "rbxassetid://10734952",
    Visible = true
})

local CreditsTab = Window:CreateTab({
    Name = "Credits",
    Icon = "rbxassetid://10747373",
    Visible = true
})

local FarmingSection = MainTab:CreateSection({
    Name = "Farming",
    Side = "Left"
})

FarmingSection:CreateToggle({
    Name = "Auto Harvest",
    Flag = "AutoHarvest",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoHarvest = value
        if value then
            CreateLoop("AutoHarvest", function()
                UpdateGameCache()
                local plants = FindAllDescendants(workspace, "plant", "Model")
                for _, plant in ipairs(plants) do
                    if plant and plant:FindFirstChild("Harvested") and plant.Harvested.Value == false then
                        local clickDetector = FindFirstDescendant(plant, nil, "ClickDetector")
                        if clickDetector then
                            fireclickdetector(clickDetector)
                        end
                        
                        local proximityPrompt = FindFirstDescendant(plant, nil, "ProximityPrompt")
                        if proximityPrompt then
                            fireproximityprompt(proximityPrompt)
                        end
                        
                        local harvestRemote = GetRemote("harvest") or GetRemote("Harvest")
                        if harvestRemote then
                            FireRemote("harvest", plant)
                        end
                    end
                end
            end, 0.5)
        else
            StopLoop("AutoHarvest")
        end
    end
})

FarmingSection:CreateToggle({
    Name = "Auto Plant",
    Flag = "AutoPlant",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoPlant = value
        if value then
            CreateLoop("AutoPlant", function()
                local plots = FindAllDescendants(workspace, "plot", "Model")
                for _, plot in ipairs(plots) do
                    if plot and plot:FindFirstChild("Occupied") and plot.Occupied.Value == false then
                        local clickDetector = FindFirstDescendant(plot, nil, "ClickDetector")
                        if clickDetector then
                            fireclickdetector(clickDetector)
                        end
                        
                        local proximityPrompt = FindFirstDescendant(plot, nil, "ProximityPrompt")
                        if proximityPrompt then
                            fireproximityprompt(proximityPrompt)
                        end
                        
                        local plantRemote = GetRemote("plant") or GetRemote("Plant")
                        if plantRemote then
                            FireRemote("plant", plot, ScriptData.Config.Main.SelectedSeed)
                        end
                    end
                end
            end, 0.5)
        else
            StopLoop("AutoPlant")
        end
    end
})

FarmingSection:CreateToggle({
    Name = "Auto Water",
    Flag = "AutoWater",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoWater = value
        if value then
            CreateLoop("AutoWater", function()
                local plants = FindAllDescendants(workspace, "plant", "Model")
                for _, plant in ipairs(plants) do
                    if plant and plant:FindFirstChild("Watered") and plant.Watered.Value == false then
                        local clickDetector = FindFirstDescendant(plant, nil, "ClickDetector")
                        if clickDetector then
                            fireclickdetector(clickDetector)
                        end
                        
                        local proximityPrompt = FindFirstDescendant(plant, nil, "ProximityPrompt")
                        if proximityPrompt then
                            fireproximityprompt(proximityPrompt)
                        end
                        
                        local waterRemote = GetRemote("water") or GetRemote("Water")
                        if waterRemote then
                            FireRemote("water", plant)
                        end
                    end
                end
            end, 0.5)
        else
            StopLoop("AutoWater")
        end
    end
})

FarmingSection:CreateToggle({
    Name = "Auto Fertilize",
    Flag = "AutoFertilize",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoFertilize = value
        if value then
            CreateLoop("AutoFertilize", function()
                local plants = FindAllDescendants(workspace, "plant", "Model")
                for _, plant in ipairs(plants) do
                    if plant then
                        local fertilizeRemote = GetRemote("fertilize") or GetRemote("Fertilize")
                        if fertilizeRemote then
                            FireRemote("fertilize", plant)
                        end
                    end
                end
            end, 1)
        else
            StopLoop("AutoFertilize")
        end
    end
})

local ShopSection = MainTab:CreateSection({
    Name = "Shop",
    Side = "Left"
})

ShopSection:CreateToggle({
    Name = "Auto Sell",
    Flag = "AutoSell",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoSell = value
        if value then
            CreateLoop("AutoSell", function()
                local sellRemote = GetRemote("sell") or GetRemote("Sell")
                if sellRemote then
                    FireRemote("sell")
                end
                
                local sellNPC = FindFirstDescendant(workspace, "sell", "Model")
                if sellNPC then
                    local clickDetector = FindFirstDescendant(sellNPC, nil, "ClickDetector")
                    if clickDetector then
                        fireclickdetector(clickDetector)
                    end
                    
                    local proximityPrompt = FindFirstDescendant(sellNPC, nil, "ProximityPrompt")
                    if proximityPrompt then
                        fireproximityprompt(proximityPrompt)
                    end
                end
            end, 2)
        else
            StopLoop("AutoSell")
        end
    end
})

ShopSection:CreateToggle({
    Name = "Auto Buy Seeds",
    Flag = "AutoBuySeeds",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoBuySeeds = value
        if value then
            CreateLoop("AutoBuySeeds", function()
                local buySeedRemote = GetRemote("buyseed") or GetRemote("BuySeed") or GetRemote("purchase")
                if buySeedRemote then
                    FireRemote("buyseed", ScriptData.Config.Main.SelectedSeed)
                end
            end, 3)
        else
            StopLoop("AutoBuySeeds")
        end
    end
})

ShopSection:CreateToggle({
    Name = "Auto Buy Gear",
    Flag = "AutoBuyGear",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoBuyGear = value
        if value then
            CreateLoop("AutoBuyGear", function()
                local buyGearRemote = GetRemote("buygear") or GetRemote("BuyGear") or GetRemote("purchase")
                if buyGearRemote then
                    FireRemote("buygear", ScriptData.Config.Main.SelectedGear)
                end
            end, 3)
        else
            StopLoop("AutoBuyGear")
        end
    end
})

local AutomationSection = MainTab:CreateSection({
    Name = "Automation",
    Side = "Right"
})

AutomationSection:CreateToggle({
    Name = "Auto Collect Drops",
    Flag = "AutoCollectDrops",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoCollectDrops = value
        if value then
            CreateLoop("AutoCollectDrops", function()
                local drops = FindAllDescendants(workspace, "drop", "BasePart")
                local root = GetRootPart()
                if root then
                    for _, drop in ipairs(drops) do
                        if drop and drop:IsA("BasePart") then
                            pcall(function()
                                drop.CFrame = root.CFrame
                            end)
                        end
                    end
                end
            end, 0.2)
        else
            StopLoop("AutoCollectDrops")
        end
    end
})

AutomationSection:CreateToggle({
    Name = "Auto Quest",
    Flag = "AutoQuest",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoQuest = value
        if value then
            CreateLoop("AutoQuest", function()
                local questRemote = GetRemote("quest") or GetRemote("Quest") or GetRemote("acceptquest")
                if questRemote then
                    FireRemote("quest")
                end
                
                local completeQuestRemote = GetRemote("completequest") or GetRemote("CompleteQuest")
                if completeQuestRemote then
                    FireRemote("completequest")
                end
            end, 2)
        else
            StopLoop("AutoQuest")
        end
    end
})

AutomationSection:CreateToggle({
    Name = "Auto Upgrade",
    Flag = "AutoUpgrade",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoUpgrade = value
        if value then
            CreateLoop("AutoUpgrade", function()
                local upgradeRemote = GetRemote("upgrade") or GetRemote("Upgrade")
                if upgradeRemote then
                    FireRemote("upgrade")
                end
            end, 3)
        else
            StopLoop("AutoUpgrade")
        end
    end
})

AutomationSection:CreateToggle({
    Name = "Auto Rebirth",
    Flag = "AutoRebirth",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoRebirth = value
        if value then
            CreateLoop("AutoRebirth", function()
                local rebirthRemote = GetRemote("rebirth") or GetRemote("Rebirth")
                if rebirthRemote then
                    FireRemote("rebirth")
                end
            end, 5)
        else
            StopLoop("AutoRebirth")
        end
    end
})

AutomationSection:CreateToggle({
    Name = "Auto Claim Rewards",
    Flag = "AutoClaimRewards",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoClaimRewards = value
        if value then
            CreateLoop("AutoClaimRewards", function()
                local claimRemote = GetRemote("claim") or GetRemote("Claim") or GetRemote("claimreward")
                if claimRemote then
                    FireRemote("claim")
                end
            end, 2)
        else
            StopLoop("AutoClaimRewards")
        end
    end
})

AutomationSection:CreateToggle({
    Name = "Auto Event",
    Flag = "AutoEvent",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoEvent = value
        if value then
            CreateLoop("AutoEvent", function()
                local eventRemote = GetRemote("event") or GetRemote("Event")
                if eventRemote then
                    FireRemote("event")
                end
            end, 2)
        else
            StopLoop("AutoEvent")
        end
    end
})

AutomationSection:CreateToggle({
    Name = "Auto Gift",
    Flag = "AutoGift",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Main.AutoGift = value
        if value then
            CreateLoop("AutoGift", function()
                local gifts = FindAllDescendants(workspace, "gift", "Model")
                for _, gift in ipairs(gifts) do
                    if gift then
                        local clickDetector = FindFirstDescendant(gift, nil, "ClickDetector")
                        if clickDetector then
                            fireclickdetector(clickDetector)
                        end
                        
                        local proximityPrompt = FindFirstDescendant(gift, nil, "ProximityPrompt")
                        if proximityPrompt then
                            fireproximityprompt(proximityPrompt)
                        end
                    end
                end
            end, 1)
        else
            StopLoop("AutoGift")
        end
    end
})

local MovementSection = PlayerTab:CreateSection({
    Name = "Movement",
    Side = "Left"
})

MovementSection:CreateSlider({
    Name = "WalkSpeed",
    Flag = "WalkSpeed",
    Min = 16,
    Max = 200,
    Value = 16,
    Callback = function(value)
        ScriptData.Config.Player.WalkSpeed = value
        local humanoid = GetHumanoid()
        if humanoid then
            humanoid.WalkSpeed = value
        end
    end
})

MovementSection:CreateSlider({
    Name = "JumpPower",
    Flag = "JumpPower",
    Min = 50,
    Max = 300,
    Value = 50,
    Callback = function(value)
        ScriptData.Config.Player.JumpPower = value
        local humanoid = GetHumanoid()
        if humanoid then
            humanoid.JumpPower = value
        end
    end
})

MovementSection:CreateSlider({
    Name = "Gravity",
    Flag = "Gravity",
    Min = 0,
    Max = 196.2,
    Value = 196.2,
    Callback = function(value)
        ScriptData.Config.Player.Gravity = value
        workspace.Gravity = value
    end
})

local FlightSection = PlayerTab:CreateSection({
    Name = "Flight",
    Side = "Left"
})

FlightSection:CreateToggle({
    Name = "Fly",
    Flag = "Fly",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Player.Fly = value
        if value then
            local flySpeed = ScriptData.Config.Player.FlySpeed
            CreateLoop("Fly", function()
                local root = GetRootPart()
                local humanoid = GetHumanoid()
                if root and humanoid then
                    local moveDirection = humanoid.MoveDirection
                    if moveDirection.Magnitude > 0 then
                        root.Velocity = moveDirection * flySpeed
                    else
                        root.Velocity = Vector3.new(0, 0, 0)
                    end
                    
                    if Services.UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                        root.Velocity = root.Velocity + Vector3.new(0, flySpeed, 0)
                    end
                    
                    if Services.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                        root.Velocity = root.Velocity - Vector3.new(0, flySpeed, 0)
                    end
                end
            end, 0.01)
        else
            StopLoop("Fly")
        end
    end
})

FlightSection:CreateSlider({
    Name = "Fly Speed",
    Flag = "FlySpeed",
    Min = 10,
    Max = 200,
    Value = 50,
    Callback = function(value)
        ScriptData.Config.Player.FlySpeed = value
    end
})

local AbilitiesSection = PlayerTab:CreateSection({
    Name = "Abilities",
    Side = "Right"
})

AbilitiesSection:CreateToggle({
    Name = "NoClip",
    Flag = "NoClip",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Player.NoClip = value
        if value then
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
            StopLoop("NoClip")
            local char = GetCharacter()
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
        end
    end
})

AbilitiesSection:CreateToggle({
    Name = "Infinite Jump",
    Flag = "InfiniteJump",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Player.InfiniteJump = value
        if value then
            AddConnection("InfiniteJump", Services.UserInputService.JumpRequest:Connect(function()
                local humanoid = GetHumanoid()
                if humanoid and ScriptData.Config.Player.InfiniteJump then
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end))
        else
            RemoveConnection("InfiniteJump")
        end
    end
})

AbilitiesSection:CreateToggle({
    Name = "Anti AFK",
    Flag = "AntiAFK",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Player.AntiAFK = value
        if value then
            AddConnection("AntiAFK", LocalPlayer.Idled:Connect(function()
                Services.VirtualUser:CaptureController()
                Services.VirtualUser:ClickButton2(Vector2.new())
            end))
        else
            RemoveConnection("AntiAFK")
        end
    end
})

AbilitiesSection:CreateToggle({
    Name = "Spinbot",
    Flag = "Spinbot",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Player.Spinbot = value
        if value then
            local angle = 0
            CreateLoop("Spinbot", function()
                local root = GetRootPart()
                if root then
                    angle = angle + ScriptData.Config.Player.SpinbotSpeed
                    root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(angle), 0)
                end
            end, 0.01)
        else
            StopLoop("Spinbot")
        end
    end
})

AbilitiesSection:CreateSlider({
    Name = "Spinbot Speed",
    Flag = "SpinbotSpeed",
    Min = 1,
    Max = 50,
    Value = 10,
    Callback = function(value)
        ScriptData.Config.Player.SpinbotSpeed = value
    end
})

AbilitiesSection:CreateButton({
    Name = "Safe Reset",
    Callback = function()
        local char = GetCharacter()
        if char then
            local humanoid = GetHumanoid()
            if humanoid then
                humanoid.Health = 0
            end
        end
    end
})

local LocationsSection = TeleportTab:CreateSection({
    Name = "Locations",
    Side = "Left"
})

LocationsSection:CreateButton({
    Name = "Teleport to Shop",
    Callback = function()
        UpdateGameCache()
        if GameCache.Shop and GameCache.Shop:FindFirstChild("HumanoidRootPart") then
            TeleportTo(GameCache.Shop.HumanoidRootPart.Position)
        elseif GameCache.Shop then
            local part = GameCache.Shop:FindFirstChildOfClass("BasePart")
            if part then
                TeleportTo(part.Position + Vector3.new(0, 5, 0))
            end
        else
            Notify("Error", "Shop not found", 3, "error")
        end
    end
})

LocationsSection:CreateButton({
    Name = "Teleport to Garden",
    Callback = function()
        UpdateGameCache()
        if GameCache.Garden and GameCache.Garden:FindFirstChild("HumanoidRootPart") then
            TeleportTo(GameCache.Garden.HumanoidRootPart.Position)
        elseif GameCache.Garden then
            local part = GameCache.Garden:FindFirstChildOfClass("BasePart")
            if part then
                TeleportTo(part.Position + Vector3.new(0, 5, 0))
            end
        else
            Notify("Error", "Garden not found", 3, "error")
        end
    end
})

LocationsSection:CreateButton({
    Name = "Teleport to Spawn",
    Callback = function()
        UpdateGameCache()
        if GameCache.Spawn then
            TeleportTo(GameCache.Spawn.Position + Vector3.new(0, 5, 0))
        else
            Notify("Error", "Spawn not found", 3, "error")
        end
    end
})

LocationsSection:CreateButton({
    Name = "Teleport to NPCs",
    Callback = function()
        UpdateGameCache()
        if #GameCache.NPCs > 0 then
            local npc = GameCache.NPCs[1]
            if npc:FindFirstChild("HumanoidRootPart") then
                TeleportTo(npc.HumanoidRootPart.Position)
            end
        else
            Notify("Error", "No NPCs found", 3, "error")
        end
    end
})

LocationsSection:CreateButton({
    Name = "Teleport to Events",
    Callback = function()
        local events = FindAllDescendants(workspace, "event", "Model")
        if #events > 0 then
            local event = events[1]
            if event:FindFirstChildOfClass("BasePart") then
                TeleportTo(event:FindFirstChildOfClass("BasePart").Position)
            end
        else
            Notify("Error", "No events found", 3, "error")
        end
    end
})

local PlayersSection = TeleportTab:CreateSection({
    Name = "Players",
    Side = "Right"
})

local selectedPlayer = nil
local playerDropdown

local function UpdatePlayerList()
    local playerNames = {}
    GameCache.PlayerList = {}
    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerNames, player.Name)
            GameCache.PlayerList[player.Name] = player
        end
    end
    return playerNames
end

playerDropdown = PlayersSection:CreateDropdown({
    Name = "Select Player",
    Flag = "SelectedPlayer",
    List = UpdatePlayerList(),
    Callback = function(value)
        selectedPlayer = value
    end
})

PlayersSection:CreateButton({
    Name = "Refresh Players",
    Callback = function()
        playerDropdown:UpdateList(UpdatePlayerList())
        Notify("Success", "Player list refreshed", 2, "success")
    end
})

PlayersSection:CreateButton({
    Name = "Teleport to Player",
    Callback = function()
        if selectedPlayer and GameCache.PlayerList[selectedPlayer] then
            local player = GameCache.PlayerList[selectedPlayer]
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                TeleportTo(player.Character.HumanoidRootPart.Position)
                Notify("Success", "Teleported to " .. selectedPlayer, 2, "success")
            else
                Notify("Error", "Player character not found", 3, "error")
            end
        else
            Notify("Error", "Please select a player", 3, "error")
        end
    end
})

local ESPSection = VisualTab:CreateSection({
    Name = "ESP",
    Side = "Left"
})

ESPSection:CreateToggle({
    Name = "Player ESP",
    Flag = "PlayerESP",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Visual.PlayerESP = value
        if value then
            CreateLoop("PlayerESP", function()
                for _, player in ipairs(Services.Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        if not ScriptData.ESPObjects[tostring(player.Character)] then
                            CreateESP(player.Character, player.Name, Color3.fromRGB(255, 0, 0))
                        end
                    end
                end
            end, 1)
        else
            StopLoop("PlayerESP")
            for _, player in ipairs(Services.Players:GetPlayers()) do
                if player.Character then
                    RemoveESP(player.Character)
                end
            end
        end
    end
})

ESPSection:CreateToggle({
    Name = "Seed ESP",
    Flag = "SeedESP",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Visual.SeedESP = value
        if value then
            CreateLoop("SeedESP", function()
                local seeds = FindAllDescendants(workspace, "seed", "Model")
                for _, seed in ipairs(seeds) do
                    if not ScriptData.ESPObjects[tostring(seed)] then
                        CreateESP(seed, "Seed", Color3.fromRGB(0, 255, 0))
                    end
                end
            end, 1)
        else
            StopLoop("SeedESP")
            ClearAllESP()
        end
    end
})

ESPSection:CreateToggle({
    Name = "Fruit ESP",
    Flag = "FruitESP",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Visual.FruitESP = value
        if value then
            CreateLoop("FruitESP", function()
                local fruits = FindAllDescendants(workspace, "fruit", "Model")
                for _, fruit in ipairs(fruits) do
                    if not ScriptData.ESPObjects[tostring(fruit)] then
                        CreateESP(fruit, "Fruit", Color3.fromRGB(255, 165, 0))
                    end
                end
            end, 1)
        else
            StopLoop("FruitESP")
        end
    end
})

ESPSection:CreateToggle({
    Name = "Item ESP",
    Flag = "ItemESP",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Visual.ItemESP = value
        if value then
            CreateLoop("ItemESP", function()
                local items = FindAllDescendants(workspace, "item", "Model")
                for _, item in ipairs(items) do
                    if not ScriptData.ESPObjects[tostring(item)] then
                        CreateESP(item, "Item", Color3.fromRGB(0, 255, 255))
                    end
                end
            end, 1)
        else
            StopLoop("ItemESP")
        end
    end
})

ESPSection:CreateToggle({
    Name = "NPC ESP",
    Flag = "NPCESP",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Visual.NPCESP = value
        if value then
            CreateLoop("NPCESP", function()
                UpdateGameCache()
                for _, npc in ipairs(GameCache.NPCs) do
                    if not ScriptData.ESPObjects[tostring(npc)] then
                        CreateESP(npc, "NPC", Color3.fromRGB(255, 255, 0))
                    end
                end
            end, 1)
        else
            StopLoop("NPCESP")
        end
    end
})

ESPSection:CreateToggle({
    Name = "Chest ESP",
    Flag = "ChestESP",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Visual.ChestESP = value
        if value then
            CreateLoop("ChestESP", function()
                local chests = FindAllDescendants(workspace, "chest", "Model")
                for _, chest in ipairs(chests) do
                    if not ScriptData.ESPObjects[tostring(chest)] then
                        CreateESP(chest, "Chest", Color3.fromRGB(255, 215, 0))
                    end
                end
            end, 1)
        else
            StopLoop("ChestESP")
        end
    end
})

local RenderSection = VisualTab:CreateSection({
    Name = "Rendering",
    Side = "Right"
})

RenderSection:CreateToggle({
    Name = "Fullbright",
    Flag = "Fullbright",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Visual.Fullbright = value
        if value then
            Services.Lighting.Brightness = 2
            Services.Lighting.ClockTime = 14
            Services.Lighting.FogEnd = 100000
            Services.Lighting.GlobalShadows = false
            Services.Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        else
            Services.Lighting.Brightness = ScriptData.OriginalValues.Brightness
            Services.Lighting.ClockTime = ScriptData.OriginalValues.ClockTime
            Services.Lighting.FogEnd = ScriptData.OriginalValues.FogEnd
            Services.Lighting.GlobalShadows = ScriptData.OriginalValues.GlobalShadows
        end
    end
})

RenderSection:CreateButton({
    Name = "Remove Fog",
    Callback = function()
        Services.Lighting.FogEnd = 100000
        for _, effect in ipairs(Services.Lighting:GetChildren()) do
            if effect:IsA("Atmosphere") or effect:IsA("BlurEffect") or effect:IsA("ColorCorrectionEffect") then
                effect:Destroy()
            end
        end
        Notify("Success", "Fog removed", 2, "success")
    end
})

RenderSection:CreateButton({
    Name = "FPS Boost",
    Callback = function()
        local decalsyeeted = true
        local g = game
        local w = g.Workspace
        local l = g.Lighting
        local t = w.Terrain
        
        t.WaterWaveSize = 0
        t.WaterWaveSpeed = 0
        t.WaterReflectance = 0
        t.WaterTransparency = 0
        l.GlobalShadows = false
        l.FogEnd = 9e9
        l.Brightness = 0
        
        settings().Rendering.QualityLevel = "Level01"
        
        for _, v in pairs(g:GetDescendants()) do
            if v:IsA("Part") or v:IsA("Union") or v:IsA("CornerWedgePart") or v:IsA("TrussPart") then
                v.Material = "Plastic"
                v.Reflectance = 0
            elseif v:IsA("Decal") or v:IsA("Texture") and decalsyeeted then
                v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
                v.Lifetime = NumberRange.new(0)
            elseif v:IsA("Explosion") then
                v.BlastPressure = 1
                v.BlastRadius = 1
            elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") then
                v.Enabled = false
            elseif v:IsA("MeshPart") then
                v.Material = "Plastic"
                v.Reflectance = 0
            end
        end
        
        for _, e in pairs(l:GetChildren()) do
            if e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("ColorCorrectionEffect") or e:IsA("BloomEffect") or e:IsA("DepthOfFieldEffect") then
                e.Enabled = false
            end
        end
        
        Notify("Success", "FPS Boost applied", 2, "success")
    end
})

RenderSection:CreateButton({
    Name = "Destroy Effects",
    Callback = function()
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                v:Destroy()
            end
        end
        Notify("Success", "Effects destroyed", 2, "success")
    end
})

local ServerSection = MiscTab:CreateSection({
    Name = "Server",
    Side = "Left"
})

ServerSection:CreateButton({
    Name = "Server Hop",
    Callback = function()
        local servers = {}
        local req = syn and syn.request or http and http.request or http_request or request
        local response = req({
            Url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
        })
        
        local body = Services.HttpService:JSONDecode(response.Body)
        if body and body.data then
            for _, server in ipairs(body.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    table.insert(servers, server)
                end
            end
        end
        
        if #servers > 0 then
            local randomServer = servers[math.random(1, #servers)]
            Services.TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServer.id, LocalPlayer)
        else
            Notify("Error", "No servers found", 3, "error")
        end
    end
})

ServerSection:CreateButton({
    Name = "Rejoin",
    Callback = function()
        Services.TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
})

ServerSection:CreateButton({
    Name = "Copy JobId",
    Callback = function()
        setclipboard(game.JobId)
        Notify("Success", "JobId copied to clipboard", 2, "success")
    end
})

ServerSection:CreateButton({
    Name = "Copy PlaceId",
    Callback = function()
        setclipboard(tostring(game.PlaceId))
        Notify("Success", "PlaceId copied to clipboard", 2, "success")
    end
})

local GameSection = MiscTab:CreateSection({
    Name = "Game",
    Side = "Right"
})

GameSection:CreateButton({
    Name = "Destroy UI",
    Callback = function()
        for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
            if gui.Name ~= "WindUI" then
                gui:Destroy()
            end
        end
        Notify("Success", "UI destroyed", 2, "success")
    end
})

local ConfigSection = SettingsTab:CreateSection({
    Name = "Configuration",
    Side = "Left"
})

local profileName = "default"

ConfigSection:CreateTextbox({
    Name = "Profile Name",
    Flag = "ProfileName",
    Value = "default",
    Placeholder = "Enter profile name...",
    Callback = function(value)
        profileName = value
    end
})

ConfigSection:CreateButton({
    Name = "Save Config",
    Callback = function()
        if SaveConfig(profileName) then
            Notify("Success", "Config saved: " .. profileName, 2, "success")
        else
            Notify("Error", "Failed to save config", 3, "error")
        end
    end
})

ConfigSection:CreateButton({
    Name = "Load Config",
    Callback = function()
        if LoadConfig(profileName) then
            Notify("Success", "Config loaded: " .. profileName, 2, "success")
        else
            Notify("Error", "Failed to load config", 3, "error")
        end
    end
})

ConfigSection:CreateToggle({
    Name = "Auto Save Config",
    Flag = "AutoSaveConfig",
    Value = false,
    Callback = function(value)
        ScriptData.Config.Settings.AutoSave = value
        if value then
            CreateLoop("AutoSave", function()
                SaveConfig(profileName)
            end, 60)
        else
            StopLoop("AutoSave")
        end
    end
})

local UISection = SettingsTab:CreateSection({
    Name = "UI Settings",
    Side = "Right"
})

UISection:CreateToggle({
    Name = "Watermark",
    Flag = "Watermark",
    Value = true,
    Callback = function(value)
        ScriptData.Config.Settings.Watermark = value
    end
})

UISection:CreateSlider({
    Name = "UI Scale",
    Flag = "UIScale",
    Min = 0.5,
    Max = 1.5,
    Value = 1,
    Callback = function(value)
        ScriptData.Config.Settings.UIScale = value
    end
})

UISection:CreateSlider({
    Name = "Transparency",
    Flag = "Transparency",
    Min = 0,
    Max = 1,
    Value = 0,
    Callback = function(value)
        ScriptData.Config.Settings.Transparency = value
    end
})

local CreditsSection = CreditsTab:CreateSection({
    Name = "Credits",
    Side = "Left"
})

CreditsSection:CreateLabel({
    Text = "Script Created by X0DEC04T"
})

CreditsSection:CreateLabel({
    Text = "Version: 1.0.0"
})

CreditsSection:CreateLabel({
    Text = "Last Updated: 2024"
})

CreditsSection:CreateLabel({
    Text = ""
})

CreditsSection:CreateLabel({
    Text = "UI Library: WindUI"
})

CreditsSection:CreateLabel({
    Text = "Game: Grow a Garden 2"
})

CreditsSection:CreateLabel({
    Text = ""
})

CreditsSection:CreateButton({
    Name = "Join Discord",
    Callback = function()
        setclipboard("discord.gg/x0dec04t")
        Notify("Success", "Discord link copied to clipboard", 2, "success")
    end
})

AddConnection("CharacterAdded", LocalPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.5)
    
    if ScriptData.Config.Player.WalkSpeed ~= ScriptData.OriginalValues.WalkSpeed then
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then
            humanoid.WalkSpeed = ScriptData.Config.Player.WalkSpeed
        end
    end
    
    if ScriptData.Config.Player.JumpPower ~= ScriptData.OriginalValues.JumpPower then
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then
            humanoid.JumpPower = ScriptData.Config.Player.JumpPower
        end
    end
end))

AddConnection("ChildAdded", workspace.ChildAdded:Connect(function(child)
    task.wait(0.1)
    UpdateGameCache()
end))

task.spawn(function()
    while task.wait(5) do
        UpdateGameCache()
    end
end)

LoadConfig("default")

Notify("X0DEC04T Hub", "Grow a Garden 2 loaded successfully!", 5, "success")

local function Cleanup()
    for name, connection in pairs(ScriptData.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    
    for name, _ in pairs(ScriptData.Loops) do
        ScriptData.Loops[name] = false
    end
    
    ClearAllESP()
    
    workspace.Gravity = ScriptData.OriginalValues.Gravity
    Services.Lighting.Brightness = ScriptData.OriginalValues.Brightness
    Services.Lighting.ClockTime = ScriptData.OriginalValues.ClockTime
    Services.Lighting.FogEnd = ScriptData.OriginalValues.FogEnd
    Services.Lighting.GlobalShadows = ScriptData.OriginalValues.GlobalShadows
    
    local humanoid = GetHumanoid()
    if humanoid then
        humanoid.WalkSpeed = ScriptData.OriginalValues.WalkSpeed
        humanoid.JumpPower = ScriptData.OriginalValues.JumpPower
    end
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        Cleanup()
    end
end)
