--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub - Grow A Garden v0.1 (STARTER TEMPLATE)
-- NEEDS diagnostic info to fill in correct remotes
--═══════════════════════════════════════════════════════════════

local LOGO_ASSET_ID = 132469099334813

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")
local VirtualUser       = game:GetService("VirtualUser")
local Lighting          = game:GetService("Lighting")
local TweenService      = game:GetService("TweenService")
local VIM               = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local INSTANCE_KEY = "__X0DEC04T_GAG_v01"
if _G[INSTANCE_KEY] then pcall(function() _G[INSTANCE_KEY].destroy() end); _G[INSTANCE_KEY] = nil; task.wait(0.2) end

local function Log(m) print("[GAG] " .. tostring(m)) end
Log("Starting GAG v0.1...")

local function safeCB(fn)
    if not fn then return function() end end
    return function(...)
        local args = table.pack(...)
        task.defer(function()
            local ok, err = pcall(function() fn(table.unpack(args, 1, args.n)) end)
            if not ok then Log("CB err: " .. tostring(err)) end
        end)
    end
end

local WindUI
local ok = pcall(function()
    WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
if not ok or not WindUI then warn("[GAG] WindUI failed"); return end

local HUB = { Name="X0DEC04T GAG", Version="0.1" }

local CM = { _list = {} }
function CM:Add(sig, cb) if not sig then return end; local ok,c=pcall(function() return sig:Connect(cb) end); if ok and c then table.insert(self._list, c); return c end end
function CM:Cleanup() for _,c in ipairs(self._list) do pcall(function() c:Disconnect() end) end; self._list={} end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- PATHS (filled from diagnostic - update as needed)
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local PATHS = {
    Gardens = Workspace:FindFirstChild("Gardens") or Workspace:FindFirstChild("_Gardens"),
    NPCs = Workspace:FindFirstChild("NPCS") or Workspace:FindFirstChild("NPCs") or Workspace:FindFirstChild("NPC"),
    Teleports = Workspace:FindFirstChild("Teleports"),
    Handles = Workspace:FindFirstChild("Handles"),
    DroppedItems = Workspace:FindFirstChild("DroppedItems"),
    PottedPlantVisuals = Workspace:FindFirstChild("PottedPlantVisuals"),
    -- ReplicatedStorage
    RemoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents"),
    Modules = ReplicatedStorage:FindFirstChild("Modules"),
    Assets = ReplicatedStorage:FindFirstChild("Assets"),
    SharedData = ReplicatedStorage:FindFirstChild("SharedData"),
    ServerValues = ReplicatedStorage:FindFirstChild("ServerValues"),
    StockValues = ReplicatedStorage:FindFirstChild("StockValues"),
    WeatherValues = ReplicatedStorage:FindFirstChild("WeatherValues"),
    GardenZoneData = ReplicatedStorage:FindFirstChild("GardenZoneData"),
}

-- REMOTES (need diagnostic to confirm - these are best guesses based on common patterns)
local function FindRemote(searchName)
    local search = searchName:lower()
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
            if obj.Name:lower():find(search) then return obj end
        end
    end
    return nil
end

local REMOTES = {
    -- These may not exist yet — send diagnostic to confirm
    Packet          = FindRemote("Packet") or FindRemote("RemoteEvent"),
    ReplicaRequest  = ReplicatedStorage:FindFirstChild("RemoteEvents") and ReplicatedStorage.RemoteEvents:FindFirstChild("ReplicaRequestData"),
    ReplicaSignal   = ReplicatedStorage:FindFirstChild("RemoteEvents") and ReplicatedStorage.RemoteEvents:FindFirstChild("ReplicaSignal"),
    -- Actions (best-guess names, need confirmation)
    Plant           = FindRemote("Plant") or FindRemote("PlaceSeed"),
    Harvest         = FindRemote("Harvest") or FindRemote("Collect"),
    Sell            = FindRemote("Sell"),
    BuySeed         = FindRemote("BuySeed") or FindRemote("PurchaseSeed"),
    BuyEgg          = FindRemote("BuyEgg"),
    HatchEgg        = FindRemote("Hatch"),
    EquipPet        = FindRemote("EquipPet"),
    Water           = FindRemote("Water"),
    Sprinkler       = FindRemote("Sprinkler"),
    ClaimReward     = FindRemote("Claim") or FindRemote("Reward"),
}

for k, v in pairs(REMOTES) do
    Log(string.format("Remote %s: %s", k, v and v:GetFullName() or "NOT FOUND"))
end

--━ STATE ━
local State = {
    -- Auto Plant
    AutoPlant = false, PlantSeedName = "Carrot", PlantDelay = 0.5,
    -- Auto Harvest
    AutoHarvest = false, HarvestDelay = 0.5, HarvestOnlyRipe = true,
    -- Auto Sell
    AutoSell = false, SellDelay = 1, SellAtValue = 10000, -- sell when carrying $X worth
    SellerName = "Steven", -- update from diagnostic
    -- Auto Buy Seeds
    AutoBuySeeds = false, BuySeedName = "Carrot", BuyQuantity = 10, BuyDelay = 1,
    ShopName = "SeedShop", -- update from diagnostic
    -- Auto Buy Egg
    AutoBuyEgg = false, EggName = "CommonEgg",
    -- Auto Hatch
    AutoHatch = false,
    -- Auto Collect drops
    AutoCollectDrops = false, CollectRadius = 50,
    -- Weather
    AutoWeather = false, PreferredWeather = "Rain",
    -- Safety
    NoFallDamage = true, GodMode = false, AntiAFK = true,
    WalkSpeed = 16, JumpPower = 50,
    -- Character TP
    TP_Target = "",
    -- Camera
    FOV = 70,
    -- Cache
    CurrentGarden = nil,
}

local function GetChar() return LocalPlayer.Character end
local function GetHRP() local ch=GetChar(); return ch and ch:FindFirstChild("HumanoidRootPart") end
local function GetHuman() local ch=GetChar(); return ch and ch:FindFirstChildOfClass("Humanoid") end
local function GuiParent() local p=CoreGui; pcall(function() if gethui then p=gethui() end end); return p end

-- Find player's own garden
local function GetMyGarden()
    if State.CurrentGarden and State.CurrentGarden.Parent then return State.CurrentGarden end
    if not PATHS.Gardens then return nil end
    for _, g in ipairs(PATHS.Gardens:GetChildren()) do
        -- Garden usually named after player or has owner attribute
        if g.Name == LocalPlayer.Name 
           or g:GetAttribute("Owner") == LocalPlayer.UserId
           or g:GetAttribute("OwnerName") == LocalPlayer.Name then
            State.CurrentGarden = g
            return g
        end
        -- Check for a nametag/sign with player name
        for _, ch in ipairs(g:GetDescendants()) do
            if ch:IsA("TextLabel") or ch:IsA("StringValue") then
                if tostring(ch.Text or ch.Value):find(LocalPlayer.Name) then
                    State.CurrentGarden = g
                    return g
                end
            end
        end
    end
    return nil
end

-- Find plants ready to harvest in my garden
local function FindHarvestablePlants()
    local garden = GetMyGarden()
    if not garden then return {} end
    local ripe = {}
    for _, obj in ipairs(garden:GetDescendants()) do
        -- Plants may have attributes like "Grown", "Ripe", "Ready", "GrowthStage"
        local ready = obj:GetAttribute("Grown") 
                   or obj:GetAttribute("Ripe") 
                   or obj:GetAttribute("Ready") 
                   or obj:GetAttribute("FullyGrown")
        if ready then
            table.insert(ripe, obj)
        elseif obj:IsA("Model") and (obj.Name:find("Plant") or obj.Name:find("Crop")) then
            -- Fallback: check ProximityPrompt exists (means interactable)
            local pp = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
            if pp then table.insert(ripe, obj) end
        end
    end
    return ripe
end

-- Find empty plots
local function FindEmptyPlots()
    local garden = GetMyGarden()
    if not garden then return {} end
    local empty = {}
    for _, obj in ipairs(garden:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name:lower():find("plot") or obj.Name:lower():find("dirt") or obj.Name:lower():find("soil")) then
            -- Empty if no plant model as child
            local hasPlant = false
            for _, ch in ipairs(obj:GetChildren()) do
                if ch:IsA("Model") then hasPlant = true; break end
            end
            if not hasPlant then table.insert(empty, obj) end
        end
    end
    return empty
end

local function FirePrompt(prompt, dur)
    if not prompt then return end
    pcall(function() if fireproximityprompt then fireproximityprompt(prompt, dur or 0.25) end end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- AUTO PLANT
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local AutoPlant = {}
function AutoPlant.PlantOnce(plot, seedName)
    -- Method 1: Equip seed tool and click plot
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local hum = GetHuman()
    if bp and hum then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find(seedName:lower()) then
                pcall(function() hum:EquipTool(t) end)
                task.wait(0.15)
                break
            end
        end
    end
    -- Method 2: Fire the Plant remote if we found one
    if REMOTES.Plant then
        pcall(function()
            if REMOTES.Plant:IsA("RemoteEvent") then
                REMOTES.Plant:FireServer(seedName, plot.Position)
            else
                REMOTES.Plant:InvokeServer(seedName, plot.Position)
            end
        end)
    end
    -- Method 3: If plot has a ProximityPrompt, fire it
    local pp = plot:FindFirstChildWhichIsA("ProximityPrompt", true)
    if pp then FirePrompt(pp) end
end

function AutoPlant.Loop()
    task.spawn(function()
        while State.AutoPlant do
            local plots = FindEmptyPlots()
            if #plots > 0 then
                for _, p in ipairs(plots) do
                    if not State.AutoPlant then break end
                    AutoPlant.PlantOnce(p, State.PlantSeedName)
                    task.wait(State.PlantDelay)
                end
            end
            task.wait(1)
        end
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- AUTO HARVEST
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local AutoHarvest = {}
function AutoHarvest.HarvestOne(plant)
    -- Method 1: ProximityPrompt
    local pp = plant:FindFirstChildWhichIsA("ProximityPrompt", true)
    if pp then FirePrompt(pp) end
    -- Method 2: Harvest remote
    if REMOTES.Harvest then
        pcall(function()
            if REMOTES.Harvest:IsA("RemoteEvent") then
                REMOTES.Harvest:FireServer(plant)
            else
                REMOTES.Harvest:InvokeServer(plant)
            end
        end)
    end
end

function AutoHarvest.Loop()
    task.spawn(function()
        while State.AutoHarvest do
            local ripe = FindHarvestablePlants()
            if #ripe > 0 then
                Log("[Harvest] Found " .. #ripe .. " ripe plants")
                for _, p in ipairs(ripe) do
                    if not State.AutoHarvest then break end
                    AutoHarvest.HarvestOne(p)
                    task.wait(State.HarvestDelay)
                end
            end
            task.wait(1)
        end
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- AUTO SELL
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local AutoSell = {}
function AutoSell.GetSellerNPC()
    if not PATHS.NPCs then return nil end
    for _, npc in ipairs(PATHS.NPCs:GetChildren()) do
        if npc.Name:lower():find(State.SellerName:lower()) 
           or npc.Name:lower():find("sell") 
           or npc.Name:lower():find("shop") then
            return npc
        end
    end
    return nil
end

function AutoSell.TPToSeller()
    local npc = AutoSell.GetSellerNPC()
    if not npc then return false end
    local hrp = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
    if not hrp then return false end
    local myHRP = GetHRP()
    if not myHRP then return false end
    pcall(function() myHRP.CFrame = hrp.CFrame + Vector3.new(0, 0, 3) end)
    task.wait(0.3)
    return true
end

function AutoSell.SellNow()
    -- Method 1: Fire sell remote
    if REMOTES.Sell then
        pcall(function()
            if REMOTES.Sell:IsA("RemoteEvent") then REMOTES.Sell:FireServer()
            else REMOTES.Sell:InvokeServer() end
        end)
    end
    -- Method 2: Fire seller NPC prompt
    local npc = AutoSell.GetSellerNPC()
    if npc then
        local pp = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
        if pp then FirePrompt(pp) end
    end
end

function AutoSell.Loop()
    task.spawn(function()
        while State.AutoSell do
            local backpack = LocalPlayer:FindFirstChild("Backpack")
            local charge = 0
            if backpack then charge = #backpack:GetChildren() end
            if charge >= 5 then -- has stuff to sell
                AutoSell.TPToSeller()
                task.wait(0.5)
                AutoSell.SellNow()
                task.wait(1)
            end
            task.wait(State.SellDelay)
        end
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- AUTO BUY SEEDS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local AutoBuySeeds = {}
function AutoBuySeeds.BuyOne(seedName)
    if REMOTES.BuySeed then
        pcall(function()
            if REMOTES.BuySeed:IsA("RemoteEvent") then REMOTES.BuySeed:FireServer(seedName)
            else REMOTES.BuySeed:InvokeServer(seedName) end
        end)
    end
    -- Fallback: generic Packet remote if exists
    if REMOTES.Packet then
        pcall(function()
            REMOTES.Packet:FireServer("BuySeed", seedName)
        end)
    end
end

function AutoBuySeeds.Loop()
    task.spawn(function()
        while State.AutoBuySeeds do
            for i=1, State.BuyQuantity do
                if not State.AutoBuySeeds then break end
                AutoBuySeeds.BuyOne(State.BuySeedName)
                task.wait(0.3)
            end
            task.wait(State.BuyDelay)
        end
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- AUTO COLLECT DROPPED ITEMS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local AutoCollect = {}
function AutoCollect.Loop()
    task.spawn(function()
        while State.AutoCollectDrops do
            if PATHS.DroppedItems then
                local hrp = GetHRP()
                if hrp then
                    for _, item in ipairs(PATHS.DroppedItems:GetChildren()) do
                        if not State.AutoCollectDrops then break end
                        local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)
                        if part then
                            local dist = (part.Position - hrp.Position).Magnitude
                            if dist <= State.CollectRadius then
                                pcall(function() hrp.CFrame = part.CFrame end)
                                task.wait(0.2)
                            end
                        end
                    end
                end
            end
            task.wait(1)
        end
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- AUTO HATCH EGGS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local AutoHatch = {}
function AutoHatch.HatchOne()
    if REMOTES.HatchEgg then
        pcall(function()
            if REMOTES.HatchEgg:IsA("RemoteEvent") then REMOTES.HatchEgg:FireServer()
            else REMOTES.HatchEgg:InvokeServer() end
        end)
    end
    -- Also try firing prompts on egg models
    local garden = GetMyGarden()
    if garden then
        for _, obj in ipairs(garden:GetDescendants()) do
            if obj:IsA("Model") and obj.Name:lower():find("egg") then
                local pp = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                if pp then FirePrompt(pp) end
            end
        end
    end
end

function AutoHatch.Loop()
    task.spawn(function()
        while State.AutoHatch do
            AutoHatch.HatchOne()
            task.wait(2)
        end
    end)
end

--━ FALL GUARD
local FallGuard = { conns={} }
local function ClearFG() for _,c in ipairs(FallGuard.conns) do pcall(function() c:Disconnect() end) end; FallGuard.conns={} end
function FallGuard.Enable()
    ClearFG()
    local h = GetHuman(); if not h then return end
    local c1 = h.StateChanged:Connect(function(_, new)
        if not State.NoFallDamage then return end
        if new == Enum.HumanoidStateType.Freefall or new == Enum.HumanoidStateType.FallingDown then
            pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
    end)
    table.insert(FallGuard.conns, c1)
    pcall(function()
        h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    end)
end
function FallGuard.Disable() ClearFG() end

if State.NoFallDamage then FallGuard.Enable() end
task.spawn(function() while task.wait(1) do if State.GodMode then local h=GetHuman(); if h then pcall(function() h.MaxHealth=math.huge; h.Health=math.huge end) end end end end)
CM:Add(LocalPlayer.Idled, function() if State.AntiAFK then pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.zero) end) end end)

--━ TP HELPER
local function TPToPos(pos)
    local hrp = GetHRP()
    if hrp then pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end) end
end

--━ UI ━
local Window = WindUI:CreateWindow({
    Title=HUB.Name, Icon="leaf", Author="v"..HUB.Version, Folder="X0DEC04T_GAG",
    Size=UDim2.fromOffset(560,460), Transparent=true, Theme="Dark", SideBarWidth=160, HasOutline=true,
})
pcall(function() WindUI:Notify({Title=HUB.Name, Content="v"..HUB.Version.." loaded", Duration=4, Icon="check"}) end)
local function Notify(t,c,d) pcall(function() WindUI:Notify({Title=t, Content=c, Duration=d or 4, Icon="info"}) end) end

-- LOGO
local logoGui, logoActive = nil, false
local function CreateLogo()
    if logoGui and logoGui.Parent then return end
    logoGui = Instance.new("ScreenGui")
    logoGui.Name="X0DEC04T_GAG_Logo"; logoGui.ResetOnSpawn=false; logoGui.IgnoreGuiInset=true
    pcall(function() logoGui.Parent = GuiParent() end)
    local btn = Instance.new("ImageButton")
    btn.Size = UDim2.new(0, 60, 0, 60)
    btn.Position = UDim2.new(0, 20, 0.5, -30)
    btn.BackgroundTransparency = 1
    btn.AutoButtonColor = false
    btn.Image = "rbxassetid://"..tostring(LOGO_ASSET_ID)
    btn.ScaleType = Enum.ScaleType.Fit
    btn.Active = true
    btn.Draggable = true
    btn.Parent = logoGui
    btn.MouseButton1Click:Connect(function()
        if logoGui then logoGui.Enabled = false end
        logoActive = false
        pcall(function() Window:Open() end)
    end)
end
CreateLogo(); if logoGui then logoGui.Enabled=false end

task.spawn(function()
    local last = true
    while task.wait(0.3) do
        if not Window then break end
        local isOpen = true
        pcall(function()
            if Window.UIElements and Window.UIElements.Main then isOpen = Window.UIElements.Main.Visible
            elseif Window.Root then isOpen = Window.Root.Visible end
        end)
        if isOpen ~= last then
            last = isOpen
            if isOpen then if logoGui then logoGui.Enabled=false end; logoActive=false
            else if logoGui then logoGui.Enabled=true end; logoActive=true end
        end
    end
end)

CM:Add(UserInputService.InputBegan, function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        task.wait(0.1)
        if logoActive then if logoGui then logoGui.Enabled=false end; logoActive=false; pcall(function() Window:Open() end)
        else if logoGui then logoGui.Enabled=true end; logoActive=true; pcall(function() Window:Close() end) end
    end
end)

local Tabs = {
    Main    = Window:Tab({Title="Main",       Icon="home"}),
    Farm    = Window:Tab({Title="Farm",       Icon="leaf"}),
    Shop    = Window:Tab({Title="Shop",       Icon="shopping-cart"}),
    Pets    = Window:Tab({Title="Pets",       Icon="paw-print"}),
    Teleport= Window:Tab({Title="Teleport",   Icon="map-pin"}),
    Player  = Window:Tab({Title="Player",     Icon="user"}),
    Settings= Window:Tab({Title="Settings",   Icon="settings"}),
}
Window:SelectTab(1)

-- MAIN
Tabs.Main:Section({Title="X0DEC04T GAG Hub v"..HUB.Version})
Tabs.Main:Paragraph({Title="Grow A Garden Bot", Desc="⚠️ STARTER TEMPLATE\n\nRemotes are auto-detected but might need manual fix.\nCheck console (F9) for [GAG] logs showing which remotes were found.\n\nSend full diagnostic output to get accurate remotes!"})
Tabs.Main:Button({Title="Minimize UI", Callback=safeCB(function() pcall(function() Window:Close() end); task.wait(0.2); if logoGui then logoGui.Enabled=true end; logoActive=true end)})

-- FARM
Tabs.Farm:Section({Title="Auto Plant"})
Tabs.Farm:Input({Title="Seed Name", Placeholder="Carrot", Default="Carrot", Callback=safeCB(function(v) State.PlantSeedName=v end)})
Tabs.Farm:Slider({Title="Plant Delay (sec x10)", Value={Min=1,Max=50,Default=5}, Step=1, Callback=safeCB(function(v) State.PlantDelay=v/10 end)})
Tabs.Farm:Toggle({Title="Auto Plant Empty Plots", Default=false, Callback=safeCB(function(v) State.AutoPlant=v; if v then AutoPlant.Loop() end end)})

Tabs.Farm:Section({Title="Auto Harvest"})
Tabs.Farm:Slider({Title="Harvest Delay (sec x10)", Value={Min=1,Max=50,Default=5}, Step=1, Callback=safeCB(function(v) State.HarvestDelay=v/10 end)})
Tabs.Farm:Toggle({Title="Only Harvest Ripe", Default=true, Callback=safeCB(function(v) State.HarvestOnlyRipe=v end)})
Tabs.Farm:Toggle({Title="Auto Harvest Ripe Plants", Default=false, Callback=safeCB(function(v) State.AutoHarvest=v; if v then AutoHarvest.Loop() end end)})

Tabs.Farm:Section({Title="Auto Sell"})
Tabs.Farm:Input({Title="Seller NPC Name", Placeholder="Steven", Default="Steven", Callback=safeCB(function(v) State.SellerName=v end)})
Tabs.Farm:Slider({Title="Sell Every (sec)", Value={Min=1,Max=60,Default=10}, Step=1, Callback=safeCB(function(v) State.SellDelay=v end)})
Tabs.Farm:Toggle({Title="Auto Sell When Full", Default=false, Callback=safeCB(function(v) State.AutoSell=v; if v then AutoSell.Loop() end end)})

Tabs.Farm:Section({Title="Manual"})
Tabs.Farm:Button({Title="Harvest All Now", Callback=safeCB(function()
    local ripe = FindHarvestablePlants()
    Log("Manual harvest: found " .. #ripe)
    for _, p in ipairs(ripe) do AutoHarvest.HarvestOne(p); task.wait(0.2) end
end)})
Tabs.Farm:Button({Title="Plant on All Empty Plots", Callback=safeCB(function()
    local plots = FindEmptyPlots()
    Log("Manual plant: found " .. #plots .. " empty")
    for _, p in ipairs(plots) do AutoPlant.PlantOnce(p, State.PlantSeedName); task.wait(0.2) end
end)})
Tabs.Farm:Button({Title="Sell All Now", Callback=safeCB(function()
    AutoSell.TPToSeller(); task.wait(0.5); AutoSell.SellNow()
end)})
Tabs.Farm:Button({Title="TP to Seller", Callback=safeCB(function() AutoSell.TPToSeller() end)})
Tabs.Farm:Button({Title="TP to My Garden", Callback=safeCB(function()
    local g = GetMyGarden()
    if g then
        local part = g:FindFirstChildWhichIsA("BasePart", true)
        if part then TPToPos(part.Position) end
    end
end)})

-- SHOP
Tabs.Shop:Section({Title="Auto Buy Seeds"})
Tabs.Shop:Input({Title="Seed to Buy", Placeholder="Carrot", Default="Carrot", Callback=safeCB(function(v) State.BuySeedName=v end)})
Tabs.Shop:Slider({Title="Quantity per Batch", Value={Min=1,Max=100,Default=10}, Step=1, Callback=safeCB(function(v) State.BuyQuantity=v end)})
Tabs.Shop:Slider({Title="Buy Delay (sec)", Value={Min=1,Max=60,Default=5}, Step=1, Callback=safeCB(function(v) State.BuyDelay=v end)})
Tabs.Shop:Toggle({Title="Auto Buy Seeds", Default=false, Callback=safeCB(function(v) State.AutoBuySeeds=v; if v then AutoBuySeeds.Loop() end end)})
Tabs.Shop:Button({Title="Buy 1 Now", Callback=safeCB(function() AutoBuySeeds.BuyOne(State.BuySeedName) end)})

Tabs.Shop:Section({Title="Auto Collect"})
Tabs.Shop:Slider({Title="Collect Radius", Value={Min=10,Max=200,Default=50}, Step=5, Callback=safeCB(function(v) State.CollectRadius=v end)})
Tabs.Shop:Toggle({Title="Auto Collect Dropped Items", Default=false, Callback=safeCB(function(v) State.AutoCollectDrops=v; if v then AutoCollect.Loop() end end)})

-- PETS
Tabs.Pets:Section({Title="Auto Hatch"})
Tabs.Pets:Toggle({Title="Auto Hatch Eggs", Default=false, Callback=safeCB(function(v) State.AutoHatch=v; if v then AutoHatch.Loop() end end)})
Tabs.Pets:Button({Title="Hatch Now", Callback=safeCB(AutoHatch.HatchOne)})

Tabs.Pets:Section({Title="Info"})
Tabs.Pets:Paragraph({Title="Pet features", Desc="Need diagnostic to add:\n• Auto equip best pet\n• Auto buy eggs from shop\n• Pet inventory list"})

-- TELEPORT
Tabs.Teleport:Section({Title="Locations"})
Tabs.Teleport:Button({Title="My Garden", Callback=safeCB(function()
    local g = GetMyGarden()
    if g then local part = g:FindFirstChildWhichIsA("BasePart", true); if part then TPToPos(part.Position) end end
end)})
Tabs.Teleport:Button({Title="Seller NPC", Callback=safeCB(function() AutoSell.TPToSeller() end)})

Tabs.Teleport:Section({Title="Auto-discovered NPCs"})
if PATHS.NPCs then
    for _, npc in ipairs(PATHS.NPCs:GetChildren()) do
        Tabs.Teleport:Button({Title="TP to "..npc.Name, Callback=safeCB(function()
            local h = npc:FindFirstChildWhichIsA("BasePart", true)
            if h then TPToPos(h.Position) end
        end)})
    end
end

Tabs.Teleport:Section({Title="Auto-discovered Teleports"})
if PATHS.Teleports then
    for _, tp in ipairs(PATHS.Teleports:GetChildren()) do
        Tabs.Teleport:Button({Title="TP to "..tp.Name, Callback=safeCB(function()
            local h = tp:IsA("BasePart") and tp or tp:FindFirstChildWhichIsA("BasePart", true)
            if h then TPToPos(h.Position) end
        end)})
    end
end

Tabs.Teleport:Section({Title="Player TP"})
Tabs.Teleport:Input({Title="Player Name", Placeholder="username", Callback=safeCB(function(v) State.TP_Target=v end)})
Tabs.Teleport:Button({Title="TP to Player", Callback=safeCB(function()
    local t = Players:FindFirstChild(State.TP_Target)
    if t and t.Character then
        local th = t.Character:FindFirstChild("HumanoidRootPart")
        if th then TPToPos(th.Position + Vector3.new(0,0,4)) end
    end
end)})

-- PLAYER
Tabs.Player:Section({Title="Movement"})
Tabs.Player:Slider({Title="Walk Speed", Value={Min=16,Max=200,Default=16}, Step=4, Callback=safeCB(function(v) State.WalkSpeed=v; local h=GetHuman(); if h then pcall(function() h.WalkSpeed=v end) end end)})
Tabs.Player:Slider({Title="Jump Power", Value={Min=50,Max=500,Default=50}, Step=10, Callback=safeCB(function(v) State.JumpPower=v; local h=GetHuman(); if h then pcall(function() h.JumpPower=v end) end end)})
Tabs.Player:Section({Title="Safety"})
Tabs.Player:Toggle({Title="No Fall Damage", Default=true, Callback=safeCB(function(v) State.NoFallDamage=v; if v then FallGuard.Enable() else FallGuard.Disable() end end)})
Tabs.Player:Toggle({Title="God Mode", Default=false, Callback=safeCB(function(v) State.GodMode=v end)})
Tabs.Player:Toggle({Title="Anti AFK", Default=true, Callback=safeCB(function(v) State.AntiAFK=v end)})

-- SETTINGS
Tabs.Settings:Section({Title="Debug"})
Tabs.Settings:Button({Title="Print All Remotes to Console", Callback=safeCB(function()
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            print("[REMOTE]", obj.ClassName, obj:GetFullName())
        end
    end
end)})
Tabs.Settings:Button({Title="Print My Garden Structure", Callback=safeCB(function()
    local g = GetMyGarden()
    if not g then Log("No garden found"); return end
    Log("Garden: " .. g:GetFullName())
    for _, ch in ipairs(g:GetChildren()) do
        Log("  " .. ch.ClassName .. " | " .. ch.Name)
    end
end)})
Tabs.Settings:Button({Title="Print Backpack", Callback=safeCB(function()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return end
    for _, t in ipairs(bp:GetChildren()) do
        Log("Tool: " .. t.Name .. " | " .. t.ClassName)
    end
end)})
Tabs.Settings:Button({Title="Minimize", Callback=safeCB(function() pcall(function() Window:Close() end); task.wait(0.2); if logoGui then logoGui.Enabled=true end; logoActive=true end)})
Tabs.Settings:Button({Title="PANIC (stop all)", Callback=safeCB(function()
    State.AutoPlant=false; State.AutoHarvest=false; State.AutoSell=false
    State.AutoBuySeeds=false; State.AutoHatch=false; State.AutoCollectDrops=false
    Notify("PANIC","All loops stopped",3)
end)})
Tabs.Settings:Button({Title="Unload", Callback=safeCB(function()
    State.AutoPlant=false; State.AutoHarvest=false; State.AutoSell=false
    State.AutoBuySeeds=false; State.AutoHatch=false; State.AutoCollectDrops=false
    FallGuard.Disable()
    if logoGui then pcall(function() logoGui:Destroy() end) end
    CM:Cleanup()
    _G[INSTANCE_KEY]=nil
    pcall(function() Window:Destroy() end)
end)})

_G[INSTANCE_KEY] = {
    version = HUB.Version,
    destroy = function()
        State.AutoPlant=false; State.AutoHarvest=false; State.AutoSell=false
        State.AutoBuySeeds=false; State.AutoHatch=false; State.AutoCollectDrops=false
        FallGuard.Disable()
        if logoGui then pcall(function() logoGui:Destroy() end) end
        CM:Cleanup()
        pcall(function() Window:Destroy() end)
    end,
}

Log("GAG v0.1 ready - CHECK CONSOLE FOR REMOTE DETECTION LOG")
