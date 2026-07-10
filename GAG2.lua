--═══════════════════════════════════════════════════════════════
-- X0DEC04T GAG v3.0 - GOD MODE (No Teleport, No UI, No Dialog)
-- Uses: Sell_Steven() direct call + Cmdr instantpurchases
--═══════════════════════════════════════════════════════════════

local LOGO_ASSET_ID = 132469099334813
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")
local VirtualUser       = game:GetService("VirtualUser")
local VIM               = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")

local INSTANCE_KEY = "__X0DEC04T_GAG_v30"
if _G[INSTANCE_KEY] then pcall(function() _G[INSTANCE_KEY].destroy() end); _G[INSTANCE_KEY]=nil; task.wait(0.2) end

local function Log(m) print("[GAG v3] "..tostring(m)) end
Log("Loading GOD MODE v3.0...")

local function safeCB(fn) if not fn then return function() end end; return function(...) local a=table.pack(...); task.defer(function() local ok,err=pcall(function() fn(table.unpack(a,1,a.n)) end); if not ok then Log("CB err: "..tostring(err)) end end) end end

local WindUI; local ok = pcall(function() WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))() end)
if not ok or not WindUI then warn("[GAG] WindUI failed"); return end

local HUB = {Name="X0DEC04T GAG", Version="3.0"}
local CM = {_list={}}
function CM:Add(sig,cb) if not sig then return end; local ok,c=pcall(function() return sig:Connect(cb) end); if ok and c then table.insert(self._list,c); return c end end
function CM:Cleanup() for _,c in ipairs(self._list) do pcall(function() c:Disconnect() end) end; self._list={} end

local genv = getgenv()
local fireproximityprompt = fireproximityprompt or genv.fireproximityprompt

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 🔑 THE MAGIC: Get Sell_Steven module + Cmdr Dispatcher
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function findDeep(parent, name)
    if not parent then return nil end
    for _, d in ipairs(parent:GetDescendants()) do
        if d.Name == name then return d end
    end
end

local SellStevenFunc = nil
local CmdrClient = nil

local function InitGodMode()
    -- Get Sell_Steven function
    local ss = findDeep(PlayerScripts, "Sell_Steven")
    if ss then
        local ok, fn = pcall(require, ss)
        if ok and type(fn) == "function" then
            SellStevenFunc = fn
            Log("✓ Sell_Steven function loaded")
        end
    end
    
    -- Get Cmdr client
    local cmdrScript = ReplicatedStorage:FindFirstChild("CmdrClient")
    if cmdrScript then
        local ok, c = pcall(require, cmdrScript)
        if ok then
            CmdrClient = c
            Log("✓ CmdrClient loaded")
        end
    end
    
    -- Enable instant purchases via Cmdr (permanent for session)
    if CmdrClient and CmdrClient.Dispatcher then
        task.spawn(function()
            task.wait(1)
            local ok, res = pcall(function()
                return CmdrClient.Dispatcher:EvaluateAndRun("instantpurchases true")
            end)
            Log("✓ instantpurchases true → "..tostring(ok).." "..tostring(res))
        end)
    end
end

InitGodMode()

-- Re-init on respawn (Sell_Steven is per-character potentially)
CM:Add(LocalPlayer.CharacterAdded, function()
    task.wait(2)
    InitGodMode()
end)

--━ SEEDS
local SEEDS = {"Carrot","Strawberry","Blueberry","Tulip","Tomato","Apple","Bamboo","Corn","Cactus","Pineapple","Mushroom","Green Bean","Banana","Grape","Coconut","Mango","Rocket Pop","Dragon Fruit","Acorn","Cherry","Sunflower","Fire Fern","Venus Fly Trap","Pomegranate","Poison Apple","Venom Spitter","Briar Rose","Moon Bloom","Hypno Bloom","Dragon's Breath","Ghost Pepper","Poison Ivy","Baby Cactus","Glow Mushroom","Romanesco","Horned Melon"}

--━ HELPERS
local function GetChar() return LocalPlayer.Character end
local function GetHRP() local c=GetChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHuman() local c=GetChar(); return c and c:FindFirstChildOfClass("Humanoid") end
local function GuiParent() local p=CoreGui; pcall(function() if gethui then p=gethui() end end); return p end

local _cachedGarden
local function GetMyGarden()
    if _cachedGarden and _cachedGarden.Parent then return _cachedGarden end
    local gardens = Workspace:FindFirstChild("Gardens")
    if not gardens then return nil end
    for _, g in ipairs(gardens:GetChildren()) do
        if g:GetAttribute("Owner")==LocalPlayer.Name or g:GetAttribute("OwnerUserId")==LocalPlayer.UserId then
            _cachedGarden=g; return g
        end
    end
end

local function FindRipeFruits()
    local garden = GetMyGarden(); if not garden then return {} end
    local plants = garden:FindFirstChild("Plants"); if not plants then return {} end
    local ripe = {}
    for _, plant in ipairs(plants:GetChildren()) do
        if plant:GetAttribute("PlantGrowthReady") then
            local fruits = plant:FindFirstChild("Fruits")
            if fruits then
                for _, fruit in ipairs(fruits:GetChildren()) do
                    for _, obj in ipairs(fruit:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") and obj.ActionText == "Harvest" then
                            table.insert(ripe, obj); break
                        end
                    end
                end
            end
        end
    end
    return ripe
end

local function GetPlotColumns()
    local garden = GetMyGarden(); if not garden then return {} end
    local cols = {}
    for _, obj in ipairs(garden:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:find("PlantAreaColumn") then table.insert(cols, obj) end
    end
    return cols
end

local function FirePrompt(p) if not p then return end; if fireproximityprompt then pcall(function() fireproximityprompt(p, p.HoldDuration or 0) end) end end

local function GetSheckles()
    local ls=LocalPlayer:FindFirstChild("leaderstats"); if not ls then return 0 end
    local s=ls:FindFirstChild("Sheckles"); return s and tonumber(s.Value) or 0
end

local function CountCrops()
    local bp=LocalPlayer:FindFirstChild("Backpack"); if not bp then return 0 end
    local n=0
    for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") and t.Name:find("%[") then n=n+1 end end
    return n
end

local function FindSeedTool(seedName)
    local bp=LocalPlayer:FindFirstChild("Backpack"); if not bp then return nil end
    local target=seedName:lower()
    for _,t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") then
            local tn=t.Name:lower()
            if tn:find(target) and not tn:find("%[") then return t end
        end
    end
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 🚀 GOD ACTIONS - No teleport, no UI, no dialog
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- INSTANT SELL - just call the function
local function DoSell()
    if not SellStevenFunc then Log("[Sell] No Sell_Steven fn"); return false end
    local before = CountCrops()
    if before == 0 then return false end
    local ok, err = pcall(SellStevenFunc)
    Log("[Sell] "..before.." crops sold → ok="..tostring(ok))
    return ok
end

-- INSTANT HARVEST - just fire prompts (bypasses distance)
local function DoHarvest()
    local ripe = FindRipeFruits()
    if #ripe==0 then return 0 end
    for _, p in ipairs(ripe) do FirePrompt(p); task.wait(0.05) end
    Log("[Harvest] "..#ripe.." fruits")
    return #ripe
end

-- INSTANT BUY - uses Cmdr instantpurchases + fires prompts on Sam remotely
-- Since instantpurchases is enabled, we just need to trigger Sam's shop remote purchase
-- Simplest: fire Sam's Interact prompt (works from anywhere) → then close shop instantly
local function GetNPC(name) local npcs=Workspace:FindFirstChild("NPCS") or Workspace:FindFirstChild("NPCs"); return npcs and npcs:FindFirstChild(name) end
local function GetInteractPrompt(npc) if not npc then return nil end; for _,o in ipairs(npc:GetDescendants()) do if o:IsA("ProximityPrompt") and (o.ActionText=="Interact" or o.ActionText=="Talk") then return o end end end

local function ClickButton(btn)
    if not btn then return end
    pcall(function()
        if getconnections then
            for _,c in ipairs(getconnections(btn.MouseButton1Click)) do pcall(function() c:Fire() end) end
            for _,c in ipairs(getconnections(btn.Activated)) do pcall(function() c:Fire() end) end
        end
    end)
end

local function DoBuySeed(seedName, quantity)
    quantity = quantity or 1
    local sam = GetNPC("Sam"); if not sam then Log("[Buy] no Sam"); return false end
    
    -- Fire Sam's prompt from anywhere (fireproximityprompt bypasses distance)
    local prompt = GetInteractPrompt(sam)
    if not prompt then Log("[Buy] no Sam prompt"); return false end
    FirePrompt(prompt)
    
    -- Wait for shop
    local shop
    local t0=tick()
    while tick()-t0 < 2 do
        shop = PlayerGui:FindFirstChild("SeedShop")
        if shop and shop.Enabled then break end
        task.wait(0.05)
    end
    if not shop or not shop.Enabled then Log("[Buy] shop didn't open"); return false end
    
    -- Find seed card
    local target = seedName:lower():gsub("%s+","")
    local card
    for _,o in ipairs(shop:GetDescendants()) do
        if o:IsA("TextLabel") or o:IsA("TextButton") then
            local txt = tostring(o.Text or ""):lower():gsub("%s+","")
            if txt == target then card = o.Parent; break end
        end
    end
    if not card then Log("[Buy] "..seedName.." not in shop"); 
        -- close shop
        for _,b in ipairs(shop:GetDescendants()) do if b.Name=="ExitButton" then ClickButton(b); break end end
        return false 
    end
    
    ClickButton(card); task.wait(0.15)
    
    -- BuyButton
    local buyBtn
    for _,b in ipairs(shop:GetDescendants()) do
        if b.Name=="BuyButton" and (b:IsA("TextButton") or b:IsA("ImageButton")) then buyBtn=b; break end
    end
    if buyBtn then
        for i=1, quantity do ClickButton(buyBtn); task.wait(0.15) end
    end
    task.wait(0.2)
    -- close
    for _,b in ipairs(shop:GetDescendants()) do if b.Name=="ExitButton" then ClickButton(b); break end end
    Log("[Buy] "..quantity.."x "..seedName)
    return true
end

-- PLANT (needs to be near plot, so we tp there for a moment)
local function DoPlant(seedName)
    local tool = FindSeedTool(seedName); if not tool then return 0 end
    local hum = GetHuman(); if not hum then return 0 end
    local hrp = GetHRP(); if not hrp then return 0 end
    local savedCF = hrp.CFrame
    
    pcall(function() hum:EquipTool(tool) end); task.wait(0.2)
    
    local plots = GetPlotColumns()
    if #plots==0 then return 0 end
    
    local planted = 0
    for _, plot in ipairs(plots) do
        local half = plot.Size.X/2
        for i=1, 8 do
            local off = -half + (half*2)*(i/9)
            local wp = plot.Position + Vector3.new(off, 5, math.random(-5,5))
            pcall(function() hrp.CFrame = CFrame.new(wp) end)
            task.wait(0.12)
            pcall(function()
                local cx,cy = Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2
                VIM:SendMouseButtonEvent(cx,cy,0,true,game,0); task.wait(0.03)
                VIM:SendMouseButtonEvent(cx,cy,0,false,game,0)
            end)
            task.wait(0.12); planted=planted+1
        end
    end
    pcall(function() hrp.CFrame = savedCF end)
    Log("[Plant] "..planted.." spots")
    return planted
end

--━ STATE
local State = {
    AutoAll=false, SeedName="Carrot", SellThreshold=20,
    NoFallDamage=true, GodMode=false, AntiAFK=true,
    DoHarvest=true, DoSell=true, DoBuy=true, DoPlant=true,
    BuyQty=10,
}

--━ FALL GUARD
local FG={conns={}}
local function ClearFG() for _,c in ipairs(FG.conns) do pcall(function() c:Disconnect() end) end; FG.conns={} end
function FG.Enable()
    ClearFG(); local h=GetHuman(); if not h then return end
    local c=h.StateChanged:Connect(function(_,new)
        if not State.NoFallDamage then return end
        if new==Enum.HumanoidStateType.Freefall or new==Enum.HumanoidStateType.FallingDown then
            pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
    end)
    table.insert(FG.conns,c)
    pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false); h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false) end)
end
function FG.Disable() ClearFG() end

--━ MASTER LOOP
local function MasterLoop()
    task.spawn(function()
        Log("═══ AUTO LOOP START (GOD MODE) ═══")
        while State.AutoAll do
            -- 1. HARVEST
            if State.DoHarvest then DoHarvest() end
            if not State.AutoAll then break end
            
            -- 2. SELL (instant, no teleport!)
            if State.DoSell and CountCrops() >= State.SellThreshold then
                DoSell(); task.wait(0.3)
            end
            if not State.AutoAll then break end
            
            -- 3. BUY seeds
            if State.DoBuy and not FindSeedTool(State.SeedName) and GetSheckles() > 20 then
                DoBuySeed(State.SeedName, State.BuyQty); task.wait(0.3)
            end
            if not State.AutoAll then break end
            
            -- 4. PLANT
            if State.DoPlant and FindSeedTool(State.SeedName) then
                DoPlant(State.SeedName)
            end
            
            task.wait(1.5)
        end
        Log("═══ LOOP STOPPED ═══")
    end)
end

--━ INIT
if State.NoFallDamage then FG.Enable() end
task.spawn(function() while task.wait(1) do if State.GodMode then local h=GetHuman(); if h then pcall(function() h.MaxHealth=math.huge; h.Health=math.huge end) end end end end)
CM:Add(LocalPlayer.Idled, function() if State.AntiAFK then pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.zero) end) end end)

--━ UI
local Window = WindUI:CreateWindow({Title=HUB.Name, Icon="leaf", Author="v"..HUB.Version.." GOD", Folder="X0DEC04T_GAG", Size=UDim2.fromOffset(560,460), Transparent=true, Theme="Dark", SideBarWidth=160, HasOutline=true})
pcall(function() WindUI:Notify({Title=HUB.Name, Content="v"..HUB.Version.." GOD MODE loaded", Duration=4, Icon="check"}) end)
local function Notify(t,c,d) pcall(function() WindUI:Notify({Title=t,Content=c,Duration=d or 4,Icon="info"}) end) end

-- Logo minimize
local logoGui, logoActive = nil, false
local function CreateLogo()
    if logoGui and logoGui.Parent then return end
    logoGui = Instance.new("ScreenGui")
    logoGui.Name="X0DEC04T_GAG_Logo"; logoGui.ResetOnSpawn=false; logoGui.IgnoreGuiInset=true
    pcall(function() logoGui.Parent = GuiParent() end)
    local btn = Instance.new("ImageButton")
    btn.Size=UDim2.new(0,60,0,60); btn.Position=UDim2.new(0,20,0.5,-30); btn.BackgroundTransparency=1
    btn.AutoButtonColor=false; btn.Image="rbxassetid://"..tostring(LOGO_ASSET_ID); btn.ScaleType=Enum.ScaleType.Fit
    btn.Active=true; btn.Draggable=true; btn.Parent=logoGui
    btn.MouseButton1Click:Connect(function()
        if logoGui then logoGui.Enabled=false end
        logoActive=false; pcall(function() Window:Open() end)
    end)
end
CreateLogo(); if logoGui then logoGui.Enabled=false end

task.spawn(function()
    local last=true
    while task.wait(0.3) do
        if not Window then break end
        local isOpen=true
        pcall(function()
            if Window.UIElements and Window.UIElements.Main then isOpen=Window.UIElements.Main.Visible
            elseif Window.Root then isOpen=Window.Root.Visible end
        end)
        if isOpen~=last then
            last=isOpen
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
    Main = Window:Tab({Title="🚀 GOD AUTO", Icon="zap"}),
    Manual = Window:Tab({Title="Manual", Icon="play"}),
    Player = Window:Tab({Title="Player", Icon="user"}),
    Settings = Window:Tab({Title="Settings", Icon="settings"}),
}
Window:SelectTab(1)

Tabs.Main:Section({Title="⚡ ZERO-TELEPORT AUTOMATION"})
Tabs.Main:Paragraph({Title="How GOD mode works", Desc="• Harvest: fires prompts remotely (no walk)\n• Sell: calls Sell_Steven() DIRECTLY (no teleport, no dialog)\n• Buy: fires Sam's prompt from anywhere + clicks shop UI\n• Plant: brief TP to plot, then back\n\nInstant purchases enabled via Cmdr on start."})

Tabs.Main:Dropdown({Title="Seed", Values=SEEDS, Value="Carrot", Callback=safeCB(function(v) State.SeedName=v end)})
Tabs.Main:Slider({Title="Sell when crops ≥", Value={Min=1,Max=50,Default=20}, Step=1, Callback=safeCB(function(v) State.SellThreshold=v end)})
Tabs.Main:Slider({Title="Buy quantity per cycle", Value={Min=1,Max=50,Default=10}, Step=1, Callback=safeCB(function(v) State.BuyQty=v end)})

Tabs.Main:Section({Title="Steps"})
Tabs.Main:Toggle({Title="✓ Harvest", Default=true, Callback=safeCB(function(v) State.DoHarvest=v end)})
Tabs.Main:Toggle({Title="✓ Sell (INSTANT)", Default=true, Callback=safeCB(function(v) State.DoSell=v end)})
Tabs.Main:Toggle({Title="✓ Buy Seeds", Default=true, Callback=safeCB(function(v) State.DoBuy=v end)})
Tabs.Main:Toggle({Title="✓ Plant", Default=true, Callback=safeCB(function(v) State.DoPlant=v end)})

Tabs.Main:Section({Title="MASTER"})
Tabs.Main:Toggle({Title="🚀 START GOD MODE", Default=false, Callback=safeCB(function(v)
    State.AutoAll=v
    if v then MasterLoop(); Notify("GOD MODE","Automation started!",4)
    else Notify("STOPPED","Bot stopped",3) end
end)})

Tabs.Manual:Section({Title="Test actions"})
Tabs.Manual:Button({Title="Harvest All", Callback=safeCB(function() Notify("Harvest",DoHarvest().." fruits",3) end)})
Tabs.Manual:Button({Title="⚡ INSTANT SELL", Callback=safeCB(function() DoSell() end)})
Tabs.Manual:Button({Title="Buy 1 Seed", Callback=safeCB(function() DoBuySeed(State.SeedName,1) end)})
Tabs.Manual:Button({Title="Buy 10 Seeds", Callback=safeCB(function() DoBuySeed(State.SeedName,10) end)})
Tabs.Manual:Button({Title="Plant Cycle", Callback=safeCB(function() DoPlant(State.SeedName) end)})
Tabs.Manual:Button({Title="Re-enable Instant Purchases", Callback=safeCB(function()
    if CmdrClient and CmdrClient.Dispatcher then
        local ok,res=pcall(function() return CmdrClient.Dispatcher:EvaluateAndRun("instantpurchases true") end)
        Notify("Cmdr", tostring(ok).." "..tostring(res), 4)
    end
end)})
Tabs.Manual:Button({Title="Show Stats", Callback=safeCB(function()
    Notify("Stats","$"..GetSheckles().." | Crops:"..CountCrops().." | Ripe:"..#FindRipeFruits(),5)
end)})

Tabs.Player:Slider({Title="Walk Speed", Value={Min=16,Max=200,Default=16}, Step=4, Callback=safeCB(function(v) local h=GetHuman(); if h then pcall(function() h.WalkSpeed=v end) end end)})
Tabs.Player:Slider({Title="Jump Power", Value={Min=50,Max=500,Default=50}, Step=10, Callback=safeCB(function(v) local h=GetHuman(); if h then pcall(function() h.JumpPower=v end) end end)})
Tabs.Player:Toggle({Title="No Fall Damage", Default=true, Callback=safeCB(function(v) State.NoFallDamage=v; if v then FG.Enable() else FG.Disable() end end)})
Tabs.Player:Toggle({Title="God Mode", Default=false, Callback=safeCB(function(v) State.GodMode=v end)})
Tabs.Player:Toggle({Title="Anti-AFK", Default=true, Callback=safeCB(function(v) State.AntiAFK=v end)})

Tabs.Settings:Button({Title="Minimize (RightShift)", Callback=safeCB(function() pcall(function() Window:Close() end); task.wait(0.2); if logoGui then logoGui.Enabled=true end; logoActive=true end)})
Tabs.Settings:Button({Title="PANIC STOP", Callback=safeCB(function() State.AutoAll=false; Notify("PANIC","Stopped",3) end)})
Tabs.Settings:Button({Title="Unload", Callback=safeCB(function()
    State.AutoAll=false; FG.Disable()
    if logoGui then pcall(function() logoGui:Destroy() end) end
    CM:Cleanup(); _G[INSTANCE_KEY]=nil
    pcall(function() Window:Destroy() end)
end)})

CM:Add(LocalPlayer.CharacterAdded, function() task.wait(1); _cachedGarden=nil; if State.NoFallDamage then FG.Enable() end end)

_G[INSTANCE_KEY] = {version=HUB.Version, destroy=function()
    State.AutoAll=false; FG.Disable()
    if logoGui then pcall(function() logoGui:Destroy() end) end
    CM:Cleanup(); pcall(function() Window:Destroy() end)
end}

Log("v3.0 GOD MODE ready | $"..GetSheckles().." | Crops:"..CountCrops())
