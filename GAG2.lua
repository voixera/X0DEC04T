--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub - Grow A Garden v1.0
-- Full auto: Plant, Harvest, Sell (Steven), Buy Seeds (Sam), Collect
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

local INSTANCE_KEY = "__X0DEC04T_GAG_v10"
if _G[INSTANCE_KEY] then pcall(function() _G[INSTANCE_KEY].destroy() end); _G[INSTANCE_KEY] = nil; task.wait(0.2) end

local function Log(m) print("[GAG] " .. tostring(m)) end
Log("Starting GAG v1.0...")

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

local HUB = { Name="X0DEC04T GAG", Version="1.0" }

local CM = { _list = {} }
function CM:Add(sig, cb) if not sig then return end; local ok,c=pcall(function() return sig:Connect(cb) end); if ok and c then table.insert(self._list, c); return c end end
function CM:Cleanup() for _,c in ipairs(self._list) do pcall(function() c:Disconnect() end) end; self._list={} end

--━ SEEDS DATA (39 seeds detected from game)
local SEEDS = {
    "Carrot", "Strawberry", "Blueberry", "Tulip", "Tomato", "Apple", "Bamboo",
    "Corn", "Cactus", "Pineapple", "Mushroom", "Green Bean", "Banana", "Grape",
    "Coconut", "Mango", "Rocket Pop", "Dragon Fruit", "Acorn", "Cherry", "Sunflower",
    "Fire Fern", "Venus Fly Trap", "Pomegranate", "Poison Apple", "Venom Spitter",
    "Briar Rose", "Moon Bloom", "Hypno Bloom", "Dragon's Breath", "Ghost Pepper",
    "Poison Ivy", "Baby Cactus", "Glow Mushroom", "Romanesco", "Horned Melon",
    "Gold", "Rainbow", "Mega"
}

--━ HELPERS
local function GetChar() return LocalPlayer.Character end
local function GetHRP() local ch=GetChar(); return ch and ch:FindFirstChild("HumanoidRootPart") end
local function GetHuman() local ch=GetChar(); return ch and ch:FindFirstChildOfClass("Humanoid") end
local function GuiParent() local p=CoreGui; pcall(function() if gethui then p=gethui() end end); return p end

-- Find MY garden by Owner attribute
local _cachedGarden
local function GetMyGarden()
    if _cachedGarden and _cachedGarden.Parent then return _cachedGarden end
    local gardens = Workspace:FindFirstChild("Gardens")
    if not gardens then return nil end
    for _, g in ipairs(gardens:GetChildren()) do
        if g:GetAttribute("Owner") == LocalPlayer.Name 
           or g:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            _cachedGarden = g
            return g
        end
    end
    return nil
end

-- Find all ripe fruits (PlantGrowthReady = true, or has Harvest prompts)
local function FindRipeFruits()
    local garden = GetMyGarden()
    if not garden then return {} end
    local plants = garden:FindFirstChild("Plants")
    if not plants then return {} end
    local ripe = {}
    for _, plant in ipairs(plants:GetChildren()) do
        -- Only if plant is grown
        if plant:GetAttribute("PlantGrowthReady") then
            local fruits = plant:FindFirstChild("Fruits")
            if fruits then
                for _, fruit in ipairs(fruits:GetChildren()) do
                    -- Look for the Harvest ProximityPrompt on this fruit
                    for _, obj in ipairs(fruit:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") and obj.ActionText == "Harvest" then
                            table.insert(ripe, {fruit=fruit, prompt=obj, plant=plant})
                            break
                        end
                    end
                end
            end
        end
    end
    return ripe
end

-- Find plot columns
local function GetPlotColumns()
    local garden = GetMyGarden()
    if not garden then return {} end
    local cols = {}
    for _, obj in ipairs(garden:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:find("PlantAreaColumn") then
            table.insert(cols, obj)
        end
    end
    return cols
end

-- Get NPC by name
local function GetNPC(name)
    local npcs = Workspace:FindFirstChild("NPCS") or Workspace:FindFirstChild("NPCs")
    if not npcs then return nil end
    return npcs:FindFirstChild(name)
end

local function GetNPCPos(name)
    local npc = GetNPC(name)
    if not npc then return nil end
    local hrp = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
    return hrp and hrp.Position
end

local function FirePrompt(prompt, dur)
    if not prompt then return false end
    local ok = pcall(function() if fireproximityprompt then fireproximityprompt(prompt, dur or 0.25) end end)
    return ok
end

local function GetTalkPrompt(npc)
    if not npc then return nil end
    for _, obj in ipairs(npc:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.ActionText == "Talk" then return obj end
    end
end

local function GetInteractPrompt(npc)
    if not npc then return nil end
    for _, obj in ipairs(npc:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.ActionText == "Interact" then return obj end
    end
end

-- TP helper
local function TPTo(pos, yOff)
    local hrp = GetHRP()
    if not hrp then return end
    pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, yOff or 3, 0)) end)
end

-- Sheckles
local function GetSheckles()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if not ls then return 0 end
    local s = ls:FindFirstChild("Sheckles")
    return s and tonumber(s.Value) or 0
end

-- Count crops in backpack (based on tools with weight [Xkg])
local function CountCrops()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return 0 end
    local n = 0
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and t.Name:find("%[") then n = n + 1 end
    end
    return n
end

--━ STATE
local State = {
    -- Auto Plant
    AutoPlant = false, PlantSeedName = "Carrot", PlantDelay = 0.4,
    -- Auto Harvest
    AutoHarvest = false, HarvestDelay = 0.15,
    -- Auto Sell
    AutoSell = false, SellDelay = 5, SellWhenCount = 20,
    -- Auto Buy Seeds
    AutoBuySeeds = false, BuySeedName = "Carrot", BuyQuantity = 10, BuyDelay = 2,
    -- Auto Collect
    AutoCollectDrops = false, CollectRadius = 100,
    -- Safety
    NoFallDamage = true, GodMode = false, AntiAFK = true,
    WalkSpeed = 16, JumpPower = 50,
    -- Camera
    FOV = 70,
    TP_Target = "",
}

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

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- AUTO HARVEST - fires "Harvest" prompt on all ripe fruits
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local AutoHarvest = {}
function AutoHarvest.HarvestAll()
    local ripe = FindRipeFruits()
    if #ripe == 0 then return 0 end
    local count = 0
    for _, r in ipairs(ripe) do
        if not State.AutoHarvest and not _G.__manualHarvest then break end
        FirePrompt(r.prompt, r.prompt.HoldDuration or 0)
        count = count + 1
        task.wait(State.HarvestDelay)
    end
    return count
end

function AutoHarvest.Loop()
    task.spawn(function()
        while State.AutoHarvest do
            local ripe = FindRipeFruits()
            if #ripe > 0 then
                Log("[Harvest] Found "..#ripe.." ripe fruits")
                for _, r in ipairs(ripe) do
                    if not State.AutoHarvest then break end
                    FirePrompt(r.prompt, r.prompt.HoldDuration or 0)
                    task.wait(State.HarvestDelay)
                end
            end
            task.wait(1)
        end
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- AUTO PLANT - equip seed tool + walk to plot + fire click
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local AutoPlant = {}

-- Find seed tool in backpack (not a harvested crop tool)
function AutoPlant.FindSeedTool(seedName)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return nil end
    local target = seedName:lower()
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") then
            local tn = t.Name:lower()
            -- Match seed name AND not a harvested crop (no kg bracket)
            if tn:find(target) and not tn:find("%[") then
                return t
            end
        end
    end
    return nil
end

function AutoPlant.EquipSeed(seedName)
    local tool = AutoPlant.FindSeedTool(seedName)
    if not tool then Log("[Plant] no seed tool: "..seedName); return false end
    local hum = GetHuman()
    if not hum then return false end
    pcall(function() hum:EquipTool(tool) end)
    task.wait(0.2)
    return GetChar() and GetChar():FindFirstChild(tool.Name) ~= nil
end

function AutoPlant.PlantOnce(plot)
    -- Walk player above plot then simulate click to plant
    local hrp = GetHRP()
    if not hrp then return end
    -- TP above plot
    local center = plot.Position + Vector3.new(math.random(-15,15), 5, math.random(-5,5))
    pcall(function() hrp.CFrame = CFrame.new(center) end)
    task.wait(0.15)
    -- Simulate mouse click at screen center to place seed
    pcall(function()
        VIM:SendMouseButtonEvent(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2, 0, true, game, 0)
        task.wait(0.05)
        VIM:SendMouseButtonEvent(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2, 0, false, game, 0)
    end)
end

function AutoPlant.PlantMany()
    if not AutoPlant.EquipSeed(State.PlantSeedName) then return end
    local plots = GetPlotColumns()
    if #plots == 0 then Log("[Plant] no plot columns"); return end
    for _, plot in ipairs(plots) do
        if not State.AutoPlant then break end
        -- Plant multiple times along the column length
        for i = 1, 3 do
            if not State.AutoPlant then break end
            AutoPlant.PlantOnce(plot)
            task.wait(State.PlantDelay)
        end
    end
end

function AutoPlant.Loop()
    task.spawn(function()
        while State.AutoPlant do
            AutoPlant.PlantMany()
            task.wait(3)
        end
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- AUTO SELL - Talk to Steven, click "Sell Inventory!"
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local AutoSell = {}

function AutoSell.OpenSteven()
    local steven = GetNPC("Steven")
    if not steven then Log("[Sell] no Steven"); return false end
    local pos = GetNPCPos("Steven")
    if not pos then return false end
    TPTo(pos + Vector3.new(3, 0, 0), 0)
    task.wait(0.4)
    -- Fire Talk prompt on Steven
    local talk = GetTalkPrompt(steven)
    if talk then FirePrompt(talk, talk.HoldDuration or 0.25) end
    task.wait(0.5)
    return true
end

function AutoSell.ClickSellInventory()
    -- Find the DialogChoice buttons in CoreGui
    local dialogFrame
    pcall(function()
        dialogFrame = CoreGui.RobloxGui.ControlFrame.BottomLeftControl.DialogFrame.UserDialogArea
    end)
    if not dialogFrame then Log("[Sell] no dialog frame"); return false end

    -- Wait up to 3s for the buttons to appear
    local t0 = tick()
    local buttons = {}
    while tick() - t0 < 3 do
        buttons = {}
        for _, b in ipairs(dialogFrame:GetDescendants()) do
            if b:IsA("TextButton") and b.Name == "RBXchatDialogSelectionButton" then
                table.insert(buttons, b)
            end
        end
        if #buttons > 0 then break end
        task.wait(0.1)
    end
    
    if #buttons == 0 then Log("[Sell] no dialog buttons"); return false end
    
    -- Click the FIRST button ("Sell Inventory!")
    local btn = buttons[1]
    Log("[Sell] Clicking dialog button #1")
    pcall(function()
        if getconnections then
            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do pcall(function() c:Fire() end) end
            for _, c in ipairs(getconnections(btn.Activated)) do pcall(function() c:Fire() end) end
        end
    end)
    if btn.AbsolutePosition and btn.AbsoluteSize then
        pcall(function()
            local c = btn.AbsolutePosition + btn.AbsoluteSize/2
            VIM:SendMouseButtonEvent(c.X, c.Y, 0, true, game, 0); task.wait(0.05)
            VIM:SendMouseButtonEvent(c.X, c.Y, 0, false, game, 0)
        end)
    end
    return true
end

function AutoSell.SellNow()
    local startCount = CountCrops()
    if startCount == 0 then Log("[Sell] nothing to sell"); return end
    local startMoney = GetSheckles()
    if not AutoSell.OpenSteven() then return end
    task.wait(0.5)
    AutoSell.ClickSellInventory()
    task.wait(1.5)
    local newMoney = GetSheckles()
    local newCount = CountCrops()
    Log(string.format("[Sell] $%d→$%d (+$%d), crops %d→%d", startMoney, newMoney, newMoney-startMoney, startCount, newCount))
end

function AutoSell.Loop()
    task.spawn(function()
        while State.AutoSell do
            if CountCrops() >= State.SellWhenCount then
                AutoSell.SellNow()
            end
            task.wait(State.SellDelay)
        end
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- AUTO BUY SEEDS - Talk to Sam, find seed in SeedShop, click buy
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local AutoBuy = {}

function AutoBuy.OpenSam()
    local sam = GetNPC("Sam")
    if not sam then Log("[Buy] no Sam"); return false end
    local pos = GetNPCPos("Sam")
    if not pos then return false end
    TPTo(pos + Vector3.new(3, 0, 0), 0)
    task.wait(0.4)
    local interact = GetInteractPrompt(sam)
    if interact then FirePrompt(interact, interact.HoldDuration or 0.25) end
    task.wait(0.5)
    return true
end

function AutoBuy.WaitForShopUI(timeout)
    local t0 = tick()
    while tick() - t0 < (timeout or 3) do
        local shop = PlayerGui:FindFirstChild("SeedShop")
        if shop and shop.Enabled then return shop end
        task.wait(0.1)
    end
    return nil
end

function AutoBuy.FindSeedCard(shop, seedName)
    local target = seedName:lower():gsub("%s+", "")
    for _, obj in ipairs(shop:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local txt = tostring(obj.Text or ""):lower():gsub("%s+", "")
            if txt == target then
                -- Return the parent card (which contains the buy button)
                return obj.Parent
            end
        end
    end
end

function AutoBuy.ClickBuyButton(shop)
    -- Try BuyButton
    for _, b in ipairs(shop:GetDescendants()) do
        if (b:IsA("TextButton") or b:IsA("ImageButton")) and b.Name == "BuyButton" then
            pcall(function()
                if getconnections then
                    for _, c in ipairs(getconnections(b.MouseButton1Click)) do pcall(function() c:Fire() end) end
                    for _, c in ipairs(getconnections(b.Activated)) do pcall(function() c:Fire() end) end
                end
            end)
            if b.AbsolutePosition and b.AbsoluteSize then
                pcall(function()
                    local c = b.AbsolutePosition + b.AbsoluteSize/2
                    VIM:SendMouseButtonEvent(c.X, c.Y, 0, true, game, 0); task.wait(0.05)
                    VIM:SendMouseButtonEvent(c.X, c.Y, 0, false, game, 0)
                end)
            end
            return true
        end
    end
    return false
end

function AutoBuy.SelectCard(card)
    if not card then return end
    -- Click the card to select the seed
    local clickTarget = card
    if not (card:IsA("TextButton") or card:IsA("ImageButton")) then
        for _, c in ipairs(card:GetDescendants()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then clickTarget = c; break end
        end
    end
    pcall(function()
        if getconnections then
            for _, c in ipairs(getconnections(clickTarget.MouseButton1Click)) do pcall(function() c:Fire() end) end
            for _, c in ipairs(getconnections(clickTarget.Activated)) do pcall(function() c:Fire() end) end
        end
    end)
    if clickTarget.AbsolutePosition and clickTarget.AbsoluteSize then
        pcall(function()
            local c = clickTarget.AbsolutePosition + clickTarget.AbsoluteSize/2
            VIM:SendMouseButtonEvent(c.X, c.Y, 0, true, game, 0); task.wait(0.05)
            VIM:SendMouseButtonEvent(c.X, c.Y, 0, false, game, 0)
        end)
    end
end

function AutoBuy.BuyOne(seedName)
    -- Open shop if not open
    local shop = PlayerGui:FindFirstChild("SeedShop")
    if not shop or not shop.Enabled then
        AutoBuy.OpenSam()
        shop = AutoBuy.WaitForShopUI(3)
    end
    if not shop then Log("[Buy] shop not open"); return false end
    -- Select the seed
    local card = AutoBuy.FindSeedCard(shop, seedName)
    if not card then Log("[Buy] seed not found in shop: "..seedName); return false end
    AutoBuy.SelectCard(card)
    task.wait(0.3)
    -- Click 1Button quantity
    for _, b in ipairs(shop:GetDescendants()) do
        if b.Name == "1Button" and (b:IsA("TextButton") or b:IsA("ImageButton")) then
            AutoBuy.SelectCard(b)
            break
        end
    end
    task.wait(0.2)
    -- Click Buy button
    AutoBuy.ClickBuyButton(shop)
    task.wait(0.3)
    return true
end

function AutoBuy.Loop()
    task.spawn(function()
        while State.AutoBuySeeds do
            AutoBuy.OpenSam()
            task.wait(0.5)
            for i=1, State.BuyQuantity do
                if not State.AutoBuySeeds then break end
                AutoBuy.BuyOne(State.BuySeedName)
                task.wait(0.5)
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
            local drops = Workspace:FindFirstChild("DroppedItems")
            if drops then
                local hrp = GetHRP()
                if hrp then
                    for _, item in ipairs(drops:GetChildren()) do
                        if not State.AutoCollectDrops then break end
                        local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)
                        if part then
                            local dist = (part.Position - hrp.Position).Magnitude
                            if dist <= State.CollectRadius then
                                pcall(function() hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0) end)
                                task.wait(0.2)
                            end
                        end
                    end
                end
            end
            task.wait(0.8)
        end
    end)
end

--━ INIT
if State.NoFallDamage then FallGuard.Enable() end
task.spawn(function() while task.wait(1) do if State.GodMode then local h=GetHuman(); if h then pcall(function() h.MaxHealth=math.huge; h.Health=math.huge end) end end end end)
CM:Add(LocalPlayer.Idled, function() if State.AntiAFK then pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.zero) end) end end)

--━ UI
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
    Main    = Window:Tab({Title="Main",      Icon="home"}),
    Farm    = Window:Tab({Title="Farm",      Icon="leaf"}),
    Shop    = Window:Tab({Title="Shop",      Icon="shopping-cart"}),
    Auto    = Window:Tab({Title="AUTO ALL",  Icon="zap"}),
    Teleport= Window:Tab({Title="Teleport",  Icon="map-pin"}),
    Player  = Window:Tab({Title="Player",    Icon="user"}),
    Settings= Window:Tab({Title="Settings",  Icon="settings"}),
}
Window:SelectTab(1)

-- MAIN
Tabs.Main:Section({Title="X0DEC04T GAG Hub v"..HUB.Version})
Tabs.Main:Paragraph({Title="Grow A Garden Bot", Desc="✓ Auto Harvest (fires ripe fruit prompts)\n✓ Auto Sell (Steven → Sell Inventory)\n✓ Auto Buy Seeds (Sam → SeedShop UI)\n✓ Auto Plant (equip + click)\n✓ Auto Collect drops\n\nRightShift = toggle UI"})
Tabs.Main:Button({Title="Minimize UI", Callback=safeCB(function() pcall(function() Window:Close() end); task.wait(0.2); if logoGui then logoGui.Enabled=true end; logoActive=true end)})

-- FARM
Tabs.Farm:Section({Title="Auto Harvest"})
Tabs.Farm:Slider({Title="Harvest Delay x100 (sec)", Value={Min=5,Max=100,Default=15}, Step=1, Callback=safeCB(function(v) State.HarvestDelay=v/100 end)})
Tabs.Farm:Toggle({Title="Auto Harvest Ripe", Default=false, Callback=safeCB(function(v) State.AutoHarvest=v; if v then AutoHarvest.Loop() end end)})
Tabs.Farm:Button({Title="Harvest All NOW", Callback=safeCB(function()
    _G.__manualHarvest = true
    local n = AutoHarvest.HarvestAll()
    _G.__manualHarvest = false
    Notify("Harvest", "Fired on "..n.." fruits", 3)
end)})

Tabs.Farm:Section({Title="Auto Plant"})
Tabs.Farm:Dropdown({Title="Seed Name", Values=SEEDS, Value="Carrot", Callback=safeCB(function(v) State.PlantSeedName=v end)})
Tabs.Farm:Slider({Title="Plant Delay x10 (sec)", Value={Min=2,Max=30,Default=4}, Step=1, Callback=safeCB(function(v) State.PlantDelay=v/10 end)})
Tabs.Farm:Toggle({Title="Auto Plant Empty Plots", Default=false, Callback=safeCB(function(v) State.AutoPlant=v; if v then AutoPlant.Loop() end end)})
Tabs.Farm:Button({Title="Plant Now (1 cycle)", Callback=safeCB(AutoPlant.PlantMany)})

Tabs.Farm:Section({Title="Auto Sell (Steven)"})
Tabs.Farm:Slider({Title="Sell When Crops ≥", Value={Min=1,Max=50,Default=20}, Step=1, Callback=safeCB(function(v) State.SellWhenCount=v end)})
Tabs.Farm:Slider({Title="Sell Check Interval (sec)", Value={Min=1,Max=60,Default=5}, Step=1, Callback=safeCB(function(v) State.SellDelay=v end)})
Tabs.Farm:Toggle({Title="Auto Sell When Full", Default=false, Callback=safeCB(function(v) State.AutoSell=v; if v then AutoSell.Loop() end end)})
Tabs.Farm:Button({Title="Sell All NOW", Callback=safeCB(AutoSell.SellNow)})

-- SHOP
Tabs.Shop:Section({Title="Auto Buy Seeds (Sam)"})
Tabs.Shop:Dropdown({Title="Seed to Buy", Values=SEEDS, Value="Carrot", Callback=safeCB(function(v) State.BuySeedName=v end)})
Tabs.Shop:Slider({Title="Quantity per Cycle", Value={Min=1,Max=100,Default=10}, Step=1, Callback=safeCB(function(v) State.BuyQuantity=v end)})
Tabs.Shop:Slider({Title="Buy Cycle Delay (sec)", Value={Min=1,Max=120,Default=10}, Step=1, Callback=safeCB(function(v) State.BuyDelay=v end)})
Tabs.Shop:Toggle({Title="Auto Buy Seeds", Default=false, Callback=safeCB(function(v) State.AutoBuySeeds=v; if v then AutoBuy.Loop() end end)})
Tabs.Shop:Button({Title="Buy 1 Now", Callback=safeCB(function() AutoBuy.BuyOne(State.BuySeedName) end)})

Tabs.Shop:Section({Title="Auto Collect Drops"})
Tabs.Shop:Slider({Title="Collect Radius", Value={Min=20,Max=300,Default=100}, Step=10, Callback=safeCB(function(v) State.CollectRadius=v end)})
Tabs.Shop:Toggle({Title="Auto Collect Dropped Items", Default=false, Callback=safeCB(function(v) State.AutoCollectDrops=v; if v then AutoCollect.Loop() end end)})

-- AUTO ALL
Tabs.Auto:Section({Title="MEGA AUTO — Farming Bot"})
Tabs.Auto:Paragraph({Title="How it works", Desc="Enable this to auto:\n1. Harvest all ripe fruits (loop)\n2. Sell to Steven when ≥20 crops\n3. Buy Carrot seeds from Sam\n4. Plant seeds in empty plots\n5. Repeat forever\n\nMake sure your default seed is set + you have money to buy seeds"})
Tabs.Auto:Toggle({Title="🚀 ENABLE FULL AUTOMATION", Default=false, Callback=safeCB(function(v)
    State.AutoHarvest = v
    State.AutoSell = v
    State.AutoBuySeeds = v
    State.AutoPlant = v
    State.AutoCollectDrops = v
    if v then
        AutoHarvest.Loop()
        AutoSell.Loop()
        AutoBuy.Loop()
        AutoPlant.Loop()
        AutoCollect.Loop()
        Notify("AUTO ALL", "Full bot started!", 4)
    else
        Notify("AUTO ALL", "All loops stopped", 3)
    end
end)})

-- TELEPORT
Tabs.Teleport:Section({Title="NPCs"})
Tabs.Teleport:Button({Title="TP to Steven (Seller)", Callback=safeCB(function() local p=GetNPCPos("Steven"); if p then TPTo(p+Vector3.new(3,0,0),0) end end)})
Tabs.Teleport:Button({Title="TP to Sam (Seed Shop)", Callback=safeCB(function() local p=GetNPCPos("Sam"); if p then TPTo(p+Vector3.new(3,0,0),0) end end)})
Tabs.Teleport:Button({Title="TP to Charlotte (Props)", Callback=safeCB(function() local p=GetNPCPos("Charlotte"); if p then TPTo(p+Vector3.new(3,0,0),0) end end)})
Tabs.Teleport:Button({Title="TP to Gilbert (Guild)", Callback=safeCB(function() local p=GetNPCPos("Gilbert"); if p then TPTo(p+Vector3.new(3,0,0),0) end end)})
Tabs.Teleport:Section({Title="My Garden"})
Tabs.Teleport:Button({Title="TP to My Garden", Callback=safeCB(function()
    local g = GetMyGarden()
    if g then
        local sp = g:FindFirstChild("SpawnPoint")
        if sp and sp:IsA("BasePart") then TPTo(sp.Position, 3)
        else local part = g:FindFirstChildWhichIsA("BasePart", true); if part then TPTo(part.Position, 3) end end
    end
end)})

Tabs.Teleport:Section({Title="Player TP"})
Tabs.Teleport:Input({Title="Player Name", Placeholder="username", Callback=safeCB(function(v) State.TP_Target=v end)})
Tabs.Teleport:Button({Title="TP to Player", Callback=safeCB(function()
    local t = Players:FindFirstChild(State.TP_Target)
    if t and t.Character then
        local th = t.Character:FindFirstChild("HumanoidRootPart")
        if th then TPTo(th.Position + Vector3.new(0,0,4)) end
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
Tabs.Settings:Section({Title="Info"})
Tabs.Settings:Button({Title="Show Sheckles", Callback=safeCB(function() Notify("Money", "$"..GetSheckles().." | Crops: "..CountCrops(), 4) end)})
Tabs.Settings:Button({Title="Show Ripe Fruits Count", Callback=safeCB(function() Notify("Farm", "Ripe: "..#FindRipeFruits(), 4) end)})
Tabs.Settings:Button({Title="Print Garden Info to Console", Callback=safeCB(function()
    local g = GetMyGarden()
    if g then
        Log("Garden: "..g.Name.." | Owner: "..tostring(g:GetAttribute("Owner")))
        local plants = g:FindFirstChild("Plants")
        if plants then Log("Plants count: "..#plants:GetChildren()) end
    end
end)})
Tabs.Settings:Button({Title="Minimize UI", Callback=safeCB(function() pcall(function() Window:Close() end); task.wait(0.2); if logoGui then logoGui.Enabled=true end; logoActive=true end)})
Tabs.Settings:Button({Title="PANIC (stop all)", Callback=safeCB(function()
    State.AutoPlant=false; State.AutoHarvest=false; State.AutoSell=false
    State.AutoBuySeeds=false; State.AutoCollectDrops=false
    Notify("PANIC","All loops stopped",3)
end)})
Tabs.Settings:Button({Title="Unload", Callback=safeCB(function()
    State.AutoPlant=false; State.AutoHarvest=false; State.AutoSell=false
    State.AutoBuySeeds=false; State.AutoCollectDrops=false
    FallGuard.Disable()
    if logoGui then pcall(function() logoGui:Destroy() end) end
    CM:Cleanup()
    _G[INSTANCE_KEY]=nil
    pcall(function() Window:Destroy() end)
end)})

CM:Add(LocalPlayer.CharacterAdded, function()
    task.wait(1)
    _cachedGarden = nil
    if State.NoFallDamage then FallGuard.Enable() end
end)

_G[INSTANCE_KEY] = {
    version = HUB.Version,
    destroy = function()
        State.AutoPlant=false; State.AutoHarvest=false; State.AutoSell=false
        State.AutoBuySeeds=false; State.AutoCollectDrops=false
        FallGuard.Disable()
        if logoGui then pcall(function() logoGui:Destroy() end) end
        CM:Cleanup()
        pcall(function() Window:Destroy() end)
    end,
}

Log("GAG v1.0 ready | Sheckles: $"..GetSheckles())
