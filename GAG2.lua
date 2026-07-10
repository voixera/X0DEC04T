--═══════════════════════════════════════════════════════════════
-- X0DEC04T GAG v2.0 - Single Toggle FULL AUTO
-- Method: prompts + UI clicks (100% reliable, no hooks needed)
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

local INSTANCE_KEY = "__X0DEC04T_GAG_v20"
if _G[INSTANCE_KEY] then pcall(function() _G[INSTANCE_KEY].destroy() end); _G[INSTANCE_KEY] = nil; task.wait(0.2) end

local function Log(m) print("[GAG] " .. tostring(m)) end
Log("Starting v2.0...")

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

local HUB = { Name="X0DEC04T GAG", Version="2.0" }

local CM = { _list = {} }
function CM:Add(sig, cb) if not sig then return end; local ok,c=pcall(function() return sig:Connect(cb) end); if ok and c then table.insert(self._list, c); return c end end
function CM:Cleanup() for _,c in ipairs(self._list) do pcall(function() c:Disconnect() end) end; self._list={} end

-- Executor globals bridge (Real Executor puts stuff in getgenv)
local genv = getgenv()
local fireproximityprompt = fireproximityprompt or genv.fireproximityprompt
local getconnections = getconnections or genv.getconnections

-- ALL SEEDS
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

local _cachedGarden
local function GetMyGarden()
    if _cachedGarden and _cachedGarden.Parent then return _cachedGarden end
    local gardens = Workspace:FindFirstChild("Gardens")
    if not gardens then return nil end
    for _, g in ipairs(gardens:GetChildren()) do
        if g:GetAttribute("Owner") == LocalPlayer.Name or g:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            _cachedGarden = g; return g
        end
    end
    return nil
end

local function FindRipeFruits()
    local garden = GetMyGarden()
    if not garden then return {} end
    local plants = garden:FindFirstChild("Plants")
    if not plants then return {} end
    local ripe = {}
    for _, plant in ipairs(plants:GetChildren()) do
        if plant:GetAttribute("PlantGrowthReady") then
            local fruits = plant:FindFirstChild("Fruits")
            if fruits then
                for _, fruit in ipairs(fruits:GetChildren()) do
                    for _, obj in ipairs(fruit:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") and obj.ActionText == "Harvest" then
                            table.insert(ripe, {prompt=obj, fruitPos=fruit:IsA("BasePart") and fruit.Position or (fruit:FindFirstChildWhichIsA("BasePart") and fruit:FindFirstChildWhichIsA("BasePart").Position)})
                            break
                        end
                    end
                end
            end
        end
    end
    return ripe
end

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

local function FirePrompt(prompt)
    if not prompt then return end
    local dur = prompt.HoldDuration or 0
    if fireproximityprompt then
        pcall(function() fireproximityprompt(prompt, dur > 0 and dur or 0) end)
    end
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

local function TPTo(pos, yOff)
    local hrp = GetHRP()
    if not hrp then return end
    pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, yOff or 3, 0)) end)
end

local function GetSheckles()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if not ls then return 0 end
    local s = ls:FindFirstChild("Sheckles")
    return s and tonumber(s.Value) or 0
end

local function CountCrops()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return 0 end
    local n = 0
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and t.Name:find("%[") then n = n + 1 end
    end
    return n
end

-- Reliable button click (works for UI + dialog)
local function ClickButton(btn)
    if not btn then return end
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
end

--━ STATE
local State = {
    AutoAll = false,
    SeedName = "Carrot",
    SellThreshold = 20,
    NoFallDamage = true, GodMode = false, AntiAFK = true,
    WalkSpeed = 16, JumpPower = 50,
    HomePos = nil,
    -- Sub-toggles (all controlled by AutoAll but can override individually)
    DoHarvest = true, DoSell = true, DoBuy = true, DoPlant = true,
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
-- ACTION: HARVEST
-- Just fires all ripe prompts (no teleport needed since prompt firing bypasses distance)
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function DoHarvest()
    local ripe = FindRipeFruits()
    if #ripe == 0 then return 0 end
    Log("[Harvest] "..#ripe.." ripe fruits")
    for _, r in ipairs(ripe) do
        FirePrompt(r.prompt)
        task.wait(0.1)
    end
    return #ripe
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ACTION: SELL (via Steven dialog)
-- Saves position, TPs to Steven, fires Talk, clicks "Sell Inventory!" button, TPs back
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function DoSell()
    local crops = CountCrops()
    if crops == 0 then return false end
    Log("[Sell] "..crops.." crops → Steven")
    
    local hrp = GetHRP()
    if not hrp then return false end
    local savedCF = hrp.CFrame
    
    local steven = GetNPC("Steven")
    if not steven then Log("[Sell] no Steven"); return false end
    local pos = GetNPCPos("Steven")
    if not pos then return false end
    
    -- TP next to Steven
    TPTo(pos + Vector3.new(3, 0, 0), 0)
    task.wait(0.4)
    
    -- Fire Talk prompt
    local talk = GetTalkPrompt(steven)
    if talk then FirePrompt(talk) end
    task.wait(0.6)
    
    -- Find & click "Sell Inventory!" dialog button
    local dialogFrame
    pcall(function()
        dialogFrame = CoreGui.RobloxGui.ControlFrame.BottomLeftControl.DialogFrame.UserDialogArea
    end)
    
    if dialogFrame then
        -- Wait up to 2s for buttons
        local t0 = tick()
        local buttons = {}
        while tick() - t0 < 2 do
            buttons = {}
            for _, b in ipairs(dialogFrame:GetDescendants()) do
                if b:IsA("TextButton") and b.Name == "RBXchatDialogSelectionButton" then
                    table.insert(buttons, b)
                end
            end
            if #buttons > 0 then break end
            task.wait(0.1)
        end
        
        -- Click button #1 ("Sell Inventory!")
        if buttons[1] then
            Log("[Sell] Click #1 (Sell Inventory!)")
            ClickButton(buttons[1])
            task.wait(1)
        else
            Log("[Sell] No dialog buttons appeared")
        end
    else
        Log("[Sell] Dialog frame not found")
    end
    
    -- Return home
    pcall(function() hrp.CFrame = savedCF end)
    task.wait(0.2)
    
    local newCrops = CountCrops()
    Log("[Sell] Done. Crops "..crops.."→"..newCrops)
    return newCrops < crops
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ACTION: BUY SEEDS (via Sam SeedShop UI)
-- TPs to Sam, fires Interact, waits for SeedShop UI, clicks seed card + Buy button
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function DoBuySeed(seedName, quantity)
    quantity = quantity or 1
    local hrp = GetHRP()
    if not hrp then return false end
    local savedCF = hrp.CFrame
    
    local sam = GetNPC("Sam")
    if not sam then Log("[Buy] no Sam"); return false end
    local pos = GetNPCPos("Sam")
    if not pos then return false end
    
    TPTo(pos + Vector3.new(3, 0, 0), 0)
    task.wait(0.4)
    
    -- Fire Interact prompt to open shop
    local interact = GetInteractPrompt(sam)
    if interact then FirePrompt(interact) end
    task.wait(0.6)
    
    -- Wait for SeedShop UI
    local shop
    local t0 = tick()
    while tick() - t0 < 3 do
        shop = PlayerGui:FindFirstChild("SeedShop")
        if shop and shop.Enabled then break end
        task.wait(0.1)
    end
    if not shop or not shop.Enabled then
        Log("[Buy] SeedShop UI didn't open")
        pcall(function() hrp.CFrame = savedCF end)
        return false
    end
    
    -- Find seed card by matching text
    local target = seedName:lower():gsub("%s+", "")
    local card
    for _, obj in ipairs(shop:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local txt = tostring(obj.Text or ""):lower():gsub("%s+", "")
            if txt == target then card = obj.Parent; break end
        end
    end
    
    if not card then
        Log("[Buy] "..seedName.." not in shop")
        pcall(function() hrp.CFrame = savedCF end)
        return false
    end
    
    Log("[Buy] Selecting "..seedName)
    ClickButton(card)
    task.wait(0.3)
    
    -- Try to click "1Button" quantity selector
    for _, b in ipairs(shop:GetDescendants()) do
        if b.Name == "1Button" and (b:IsA("TextButton") or b:IsA("ImageButton")) then
            ClickButton(b); break
        end
    end
    task.wait(0.2)
    
    -- Click BuyButton multiple times
    local buyBtn
    for _, b in ipairs(shop:GetDescendants()) do
        if b.Name == "BuyButton" and (b:IsA("TextButton") or b:IsA("ImageButton")) then
            buyBtn = b; break
        end
    end
    
    if buyBtn then
        for i=1, quantity do
            ClickButton(buyBtn)
            task.wait(0.3)
        end
    else
        Log("[Buy] No BuyButton")
    end
    
    task.wait(0.4)
    -- Close shop by pressing exit
    for _, b in ipairs(shop:GetDescendants()) do
        if b.Name == "ExitButton" and (b:IsA("TextButton") or b:IsA("ImageButton")) then
            ClickButton(b); break
        end
    end
    
    -- TP back
    pcall(function() hrp.CFrame = savedCF end)
    return true
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ACTION: PLANT (equip seed tool + click above plots)
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function FindSeedTool(seedName)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return nil end
    local target = seedName:lower()
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") then
            local tn = t.Name:lower()
            if tn:find(target) and not tn:find("%[") then return t end
        end
    end
    return nil
end

local function DoPlant(seedName)
    local tool = FindSeedTool(seedName)
    if not tool then Log("[Plant] no seed: "..seedName); return 0 end
    local hum = GetHuman()
    if not hum then return 0 end
    
    -- Equip seed
    pcall(function() hum:EquipTool(tool) end)
    task.wait(0.25)
    
    local hrp = GetHRP()
    if not hrp then return 0 end
    local savedCF = hrp.CFrame
    
    local plots = GetPlotColumns()
    if #plots == 0 then Log("[Plant] no plots"); return 0 end
    
    local planted = 0
    for _, plot in ipairs(plots) do
        -- Try planting 8 times along the column length
        local half = plot.Size.X / 2
        for i = 1, 8 do
            local offset = -half + (half * 2) * (i / 9)
            local worldPos = plot.Position + Vector3.new(offset, 5, math.random(-5, 5))
            pcall(function() hrp.CFrame = CFrame.new(worldPos) end)
            task.wait(0.15)
            -- Simulate click at screen center
            pcall(function()
                local cx, cy = Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2
                VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                task.wait(0.05)
                VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            end)
            task.wait(0.15)
            planted = planted + 1
        end
    end
    
    pcall(function() hrp.CFrame = savedCF end)
    Log("[Plant] Attempted "..planted.." spots")
    return planted
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SINGLE MASTER LOOP
-- Priority: Harvest → Sell (if full) → Buy seeds → Plant
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function MasterLoop()
    task.spawn(function()
        Log("═══ AUTO LOOP STARTED ═══")
        while State.AutoAll do
            -- 1. HARVEST (always)
            if State.DoHarvest then
                DoHarvest()
                if not State.AutoAll then break end
            end
            
            -- 2. SELL if enough crops
            if State.DoSell and CountCrops() >= State.SellThreshold then
                DoSell()
                if not State.AutoAll then break end
                task.wait(0.5)
            end
            
            -- 3. BUY seeds if we don't have any
            if State.DoBuy then
                local hasSeed = FindSeedTool(State.SeedName) ~= nil
                if not hasSeed and GetSheckles() > 20 then
                    DoBuySeed(State.SeedName, 10)
                    if not State.AutoAll then break end
                    task.wait(0.5)
                end
            end
            
            -- 4. PLANT if we have seeds
            if State.DoPlant then
                if FindSeedTool(State.SeedName) then
                    DoPlant(State.SeedName)
                    if not State.AutoAll then break end
                end
            end
            
            task.wait(1.5)
        end
        Log("═══ AUTO LOOP STOPPED ═══")
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
    btn.Active = true; btn.Draggable = true; btn.Parent = logoGui
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
    Main    = Window:Tab({Title="MAIN AUTO",  Icon="zap"}),
    Manual  = Window:Tab({Title="Manual",     Icon="play"}),
    Teleport= Window:Tab({Title="Teleport",   Icon="map-pin"}),
    Player  = Window:Tab({Title="Player",     Icon="user"}),
    Settings= Window:Tab({Title="Settings",   Icon="settings"}),
}
Window:SelectTab(1)

-- MAIN AUTO
Tabs.Main:Section({Title="🚀 One-Toggle Automation"})
Tabs.Main:Paragraph({Title="How the bot works", Desc="Loop: harvest ripe fruits → sell when 20+ crops → buy seeds if empty → plant seeds → repeat.\n\nRunning forever until you toggle off."})

Tabs.Main:Section({Title="Config"})
Tabs.Main:Dropdown({Title="Seed to Plant & Buy", Values=SEEDS, Value="Carrot", Callback=safeCB(function(v) State.SeedName=v end)})
Tabs.Main:Slider({Title="Sell when crops ≥", Value={Min=1,Max=50,Default=20}, Step=1, Callback=safeCB(function(v) State.SellThreshold=v end)})

Tabs.Main:Section({Title="Enable/Disable steps"})
Tabs.Main:Toggle({Title="✓ Do Harvest", Default=true, Callback=safeCB(function(v) State.DoHarvest=v end)})
Tabs.Main:Toggle({Title="✓ Do Sell", Default=true, Callback=safeCB(function(v) State.DoSell=v end)})
Tabs.Main:Toggle({Title="✓ Do Buy Seeds", Default=true, Callback=safeCB(function(v) State.DoBuy=v end)})
Tabs.Main:Toggle({Title="✓ Do Plant", Default=true, Callback=safeCB(function(v) State.DoPlant=v end)})

Tabs.Main:Section({Title="MASTER TOGGLE"})
Tabs.Main:Toggle({Title="🚀 START FULL AUTOMATION", Default=false, Callback=safeCB(function(v)
    State.AutoAll = v
    if v then
        MasterLoop()
        Notify("AUTO", "Full bot started!", 4)
    else
        Notify("AUTO", "Bot stopped", 3)
    end
end)})

-- MANUAL
Tabs.Manual:Section({Title="Test each action"})
Tabs.Manual:Button({Title="Harvest All Ripe", Callback=safeCB(function() local n=DoHarvest(); Notify("Harvest",n.." fruits",3) end)})
Tabs.Manual:Button({Title="Sell to Steven Now", Callback=safeCB(DoSell)})
Tabs.Manual:Button({Title="Buy 1 Seed from Sam", Callback=safeCB(function() DoBuySeed(State.SeedName,1) end)})
Tabs.Manual:Button({Title="Buy 10 Seeds from Sam", Callback=safeCB(function() DoBuySeed(State.SeedName,10) end)})
Tabs.Manual:Button({Title="Plant Cycle (all plots)", Callback=safeCB(function() DoPlant(State.SeedName) end)})
Tabs.Manual:Section({Title="Info"})
Tabs.Manual:Button({Title="Show Stats", Callback=safeCB(function()
    Notify("Stats", "$"..GetSheckles().." | Crops: "..CountCrops().." | Ripe: "..#FindRipeFruits(), 5)
end)})

-- TELEPORT
Tabs.Teleport:Section({Title="NPCs"})
Tabs.Teleport:Button({Title="Steven (Seller)", Callback=safeCB(function() local p=GetNPCPos("Steven"); if p then TPTo(p+Vector3.new(3,0,0),0) end end)})
Tabs.Teleport:Button({Title="Sam (Seed Shop)", Callback=safeCB(function() local p=GetNPCPos("Sam"); if p then TPTo(p+Vector3.new(3,0,0),0) end end)})
Tabs.Teleport:Button({Title="Charlotte (Props)", Callback=safeCB(function() local p=GetNPCPos("Charlotte"); if p then TPTo(p+Vector3.new(3,0,0),0) end end)})
Tabs.Teleport:Button({Title="Gilbert (Guild)", Callback=safeCB(function() local p=GetNPCPos("Gilbert"); if p then TPTo(p+Vector3.new(3,0,0),0) end end)})
Tabs.Teleport:Section({Title="My Garden"})
Tabs.Teleport:Button({Title="TP to My Garden", Callback=safeCB(function()
    local g = GetMyGarden()
    if g then
        local sp = g:FindFirstChild("SpawnPoint")
        if sp and sp:IsA("BasePart") then TPTo(sp.Position, 3)
        else local part = g:FindFirstChildWhichIsA("BasePart", true); if part then TPTo(part.Position, 3) end end
    end
end)})

-- PLAYER
Tabs.Player:Slider({Title="Walk Speed", Value={Min=16,Max=200,Default=16}, Step=4, Callback=safeCB(function(v) local h=GetHuman(); if h then pcall(function() h.WalkSpeed=v end) end end)})
Tabs.Player:Slider({Title="Jump Power", Value={Min=50,Max=500,Default=50}, Step=10, Callback=safeCB(function(v) local h=GetHuman(); if h then pcall(function() h.JumpPower=v end) end end)})
Tabs.Player:Toggle({Title="No Fall Damage", Default=true, Callback=safeCB(function(v) State.NoFallDamage=v; if v then FallGuard.Enable() else FallGuard.Disable() end end)})
Tabs.Player:Toggle({Title="God Mode", Default=false, Callback=safeCB(function(v) State.GodMode=v end)})
Tabs.Player:Toggle({Title="Anti-AFK", Default=true, Callback=safeCB(function(v) State.AntiAFK=v end)})

-- SETTINGS
Tabs.Settings:Button({Title="Minimize UI (or RightShift)", Callback=safeCB(function() pcall(function() Window:Close() end); task.wait(0.2); if logoGui then logoGui.Enabled=true end; logoActive=true end)})
Tabs.Settings:Button({Title="PANIC (stop all)", Callback=safeCB(function() State.AutoAll=false; Notify("PANIC","Stopped",3) end)})
Tabs.Settings:Button({Title="Unload", Callback=safeCB(function()
    State.AutoAll=false; FallGuard.Disable()
    if logoGui then pcall(function() logoGui:Destroy() end) end
    CM:Cleanup(); _G[INSTANCE_KEY]=nil
    pcall(function() Window:Destroy() end)
end)})

CM:Add(LocalPlayer.CharacterAdded, function()
    task.wait(1); _cachedGarden = nil
    if State.NoFallDamage then FallGuard.Enable() end
end)

_G[INSTANCE_KEY] = {
    version = HUB.Version,
    destroy = function()
        State.AutoAll=false; FallGuard.Disable()
        if logoGui then pcall(function() logoGui:Destroy() end) end
        CM:Cleanup(); pcall(function() Window:Destroy() end)
    end,
}

Log("GAG v2.0 ready | $"..GetSheckles().." | Crops: "..CountCrops())
