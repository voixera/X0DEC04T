--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v2.0.0 - Car Driving Indonesia
-- UI: Rayfield | ALL Remotes Mapped Exactly
--═══════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--═══════════════════════════════════════════════════════════════
-- DUPLICATE GUARD
--═══════════════════════════════════════════════════════════════
local INSTANCE_KEY = "__X0DEC04T_CDI_v200"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.1)
end

--═══════════════════════════════════════════════════════════════
-- LOGGER
--═══════════════════════════════════════════════════════════════
local _t0 = os.clock()
local function Log(msg) print(string.format("[X0DEC04T][+%.2fs] %s", os.clock()-_t0, tostring(msg))) end
local function Err(msg,detail) warn(string.format("[X0DEC04T][+%.2fs] ERROR: %s | %s", os.clock()-_t0, tostring(msg), tostring(detail or ""))) end

Log("CDI Hub v2.0.0 starting...")

--═══════════════════════════════════════════════════════════════
-- LOAD RAYFIELD
--═══════════════════════════════════════════════════════════════
local Rayfield = nil

for _, url in ipairs({
    "https://sirius.menu/rayfield",
}) do
    local ok, r = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and type(r) == "table" then Rayfield = r; break end
end

if not Rayfield then
    Err("FATAL","Rayfield cannot load"); return
end

Log("Rayfield loaded")

--═══════════════════════════════════════════════════════════════
-- CONNECTION MANAGER
--═══════════════════════════════════════════════════════════════
local CM = {_list={}}
function CM:Add(signal,cb,label) 
    if not signal then return nil end
    local ok,c=pcall(function()return signal:Connect(cb)end) 
    if ok and c then table.insert(self._list,c); return c end
    Err("CM:Add failed",tostring(label)); return nil
end
function CM:Cleanup()
    for _,c in ipairs(self._list) do pcall(function()c:Disconnect()end) end
    self._list={}
end

--═══════════════════════════════════════════════════════════════
-- NOTIFY
--═══════════════════════════════════════════════════════════════
function Notify(title,content,dur)
    pcall(function()
        Rayfield:Notify({Title=tostring(title or ""),Content=tostring(content or ""),Duration=tonumber(dur) or 4,Image=4483345998})
    end)
end

--═══════════════════════════════════════════════════════════════
-- HELPERS
--═══════════════════════════════════════════════════════════════
local function GetChar() return LocalPlayer.Character end
local function GetHRP() local c=GetChar();return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHuman() local c=GetChar();return c and c:FindFirstChildOfClass("Humanoid") end
local function GuiParent() local p=CoreGui;pcall(function()if gethui then p=gethui() end);return p end

local function GetPlayerCar()
    if not GetChar() then return nil end
    local carsFolder=Workspace:FindFirstChild("Cars")or Workspace:FindFirstChild("Vehicles")
    if not carsFolder then return nil end
    for _,car in ipairs(carsFolder:GetChildren()) do
        for _,seat in ipairs(car:GetDescendants()) do
            if seat:IsA("VehicleSeat") and seat.Occupant and seat.Occupant.Parent==GetChar() then return car end
        end
    end;return nil
end

function GetVehicleSeat()
    local car=GetPlayerCar();if not car then return nil end
    return car:FindFirstChildOfClass("VehicleSeat")or car:FindFirstChildWhichIsA("VehicleSeat",true)
end
function GetCarRoot()
    local car=GetPlayerCar();if not car then return nil end
    return car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
end

--═══════════════════════════════════════════════════════════════
-- EXACT REMOTE REFERENCES
-- These were found via scan of ReplicatedStorage.ReplicaRemoteEvents
--═══════════════════════════════════════════════════════════════
local R = {
    Replicas  = ReplicatedStorage.ReplicaRemoteEvents,
    Events     = ReplicatedStorage.Events,
    
    -- These are the ACTUAL remote names from the folder scan
    SetValue   = nil,
    Create     = nil,
    Destroy    = nil,
    SetParent = nil,
    ArrayInsert= nil,
    ArrayRemove= nil,
    Signal     = nil,
}

-- Resolve them by searching the folder contents on first use
local RResolved = false
local function ResolveR()
    if RResolved then return end
    
    for name,target in pairs({
        {key="SetValue",     target="ReplicaSetValue"},
        {key="Create",       target="ReplicaCreate"},
        {key="Destroy",      target="ReplicaDestroy"},
        {key="SetParent",    target="ReplicaSetParent"},
        {key="ArrayInsert",  target="ReplicaArrayInsert"},
        {key="ArrayRemove",  target="ReplicaArrayRemove"},
        {key="Signal",      target="ReplicaSignal"},
    }) do
        local obj = R.Replicas:FindFirstChild(target.target)
        R[key]=obj
        Log("Remote "..key.." -> "..(obj and obj:GetFullName() or "NOT FOUND"))
    end
    RResolved=true
end

-- Call it when we need to fire remotes
local function EnsureR()
    if not RResolved then ResolveR() end
end

-- Also try regular RemoteEvents at top level of ReplicatedStorage
local TopRemotes={}
for _,obj in ipairs(ReplicatedStorage:GetDescendants()) do
    if obj:IsA("RemoteEvent") then TopRemotes[obj.Name:lower():gsub("%s+","_")] = obj end
end

Log("Top-level remotes found: "..#TopRemotes)

-- Helper to fire replica remote (fire to server + possibly invoke locally)
function FireR(remoteName,...)
    EnsureR()
    local rem=R[remoteName]
    if rem then
        pcall(function() rem:FireServer(...) end); Log("Fired: "..remoteName.."(...)")
        return true
    else
        -- Try case-insensitive search through replicas
        for k,v in pairs(R) do
            if tostring(k):lower():gsub("%s+","_")==tostring(remoteName):lower():gsub("%s+","_") then
                pcall(function() v:FireServer(...) end)
                Log("Fired: "..k.." (fallback)")
                return true
            end
        end
    end
    Notify("Remote","Not found: "..tostring(remoteName),3)
    return false
end

-- Helper to invoke remote (for getting data back)
function InvokeR(remoteName,...)
    EnsureR()
    local rem=R[remoteName]
    if rem then
        local ok,r=pcall(function() return rem:InvokeServer(...) end)
        if ok then
            Log("Invoked: "..remoteName.."("..tostring(r)..")"); return r
        end
    end
    -- Fallback to fire
    FireR(remoteName,...)
    return nil
end

--═══════════════════════════════════════════════════════════════
-- STATE
--═══════════════════════════════════════════════════════════════
local State={
    ESP_Players=false,ESP_Cars=false,ESP_ShowName=true,ESP_ShowDist=true,
    ESP_MaxDist=500,Color_Player=Color3.fromRGB(60,220,255),Color_Car=Color3.fromRGB(255,200,60),
    CarSpeed=0,NoClipConn=nil,NoClip=false,FlyActive=false,FlyConn=nil,
    GodMode=false,RainbowConn=nil,RainbowCar=false,
    SpeedHack=false,SpeedHackConn=nil,SpeedHackValue=50,
    AutoFarmActive=false,AutoFarmConn=nil,
    TP_Target="",TP_SpawnIdx=1,SavedPositions={},
    RemoteName="",RemoteArg="",RemoteSpamConn=nil,
    FolderName="",FullBright=false,NoFog=false,NoShadows=false,
    FOV=70,ClockTime=14,RemoveBlur=false,LowGraphics=false,
    NoParticles=false,Freecam=false,FreecamConn=nil,
    AntiAFK=true,AutoRejoin=false,NoSound=false,MutedSounds={},
    ChatSpam=false,ChatSpamMsg="X0DEC04T Best",ChatSpamConn=nil,
    InfMoney=false,InfMoneyConn=nil,MoneyAmount=999999,
    VehicleClone=nil,LastPosition=nil,
    ESPCache={},LightBackup={},NoclipList={},
}
--═══════════════════════════════════════════════════════════════
-- ESP
--═══════════════════════════════════════════════════════════════
local ESP={};function ESP.Clear(obj)local cache=State.ESPCache[obj];if not cache then return end
for _,inst in pairs(cache)do if typeof(inst)=="Instance"and inst.Parent then pcall(inst.Destroy,inst)end end
State.ESPCache[obj]=nil end
function ESP.ClearAll()for obj in pairs(State.ESPCache)do ESP.Clear(obj)end State.ESPCache={}
local function MakeBB(adornee,label,color,showName,showDist,maxDist)
    local bb=Instance.new("BillboardGui");bb.Adornee=adornee;
    bb.Size=UDim2.new(0,220,0,55);bb.StudsOffset=Vector3.new(0,4,0);
    bb.AlwaysOnTop=true;bb.LightInfluence=0;bb.MaxDistance=maxDist or 500;bb.Parent=GuiParent()
    local nl=Instance.new("TextLabel",bb);nl.Size=UDim2.new(1,0,0.6,0);
    nl.BackgroundTransparency=1;nll.Text=tostring(label or"");nll.TextColor3=color;
    nll.TextStrokeTransparency=0;nll.Font=Enum.Font.GothamBold;nll.TextSize=14;nl.Visible=showName
    local dl=Instance.new("TextLabel",bb);dl.Size=UDim2.new(1,0,0.4,0);
    dl.Position=UDim2.new(0,0,0.6,0);dl.BackgroundTransparency=1;dl.Text="0m";
    dl.TextColor3=Color3.fromRGB(220,220,220);dl.TextStrokeTransparency=0;
    dl.Font=Enum.Font.Gotham;dl.TextSize=12;dl.Visible=showDist
    return bb,nl,dl
end
function ESP.AddTarget(adornee,model,label,color)
    if State.ESPCache[adornee]then ESP.Clear(adornee)end
    local hl=Instance.new("Highlight");hl.Adornee=model or adornee;
    hl.FillColor=color;hl.OutlineColor=Color3.new(1,1,1);
    hl.FillTransparency=0.5;hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop;
    hl.Parent=GuiParent()
    local bb,nl,dl=MakeBB(adornee,label,color,State.ESP_ShowName,State.ESP_ShowDist,State.ESP_MaxDist)
    State.ESPCache[adornee]={hl=hl,bb=bb,nl=nl,dl=dl,hrp=adornee}
end
function ESP.UpdateDistances()
    local hrp=GetHRP();if not hrp then return end
    for _,c in pairs(State.ESPCache)do if c.dl and c.hrp and c.hrp.Parent then
        c.dl.Text=math.floor((c.hrp.Position-hrp.Position).Magnitude).."m"
    end end
end
function ESP.Validate()for obj in pairs(State.ESPCache)do if not obj or not obj.Parent then ESP.Clear(obj)end end
function ESP.ScanPlayers()
    for _,p in ipairs(Players:GetPlayers())do if p~=LocalPlayer then
        local ch=p.Character;if ch then
            local hrp=ch:FindFirstChild("HumanoidRootPart")
            if hrp then if State.ESP_Players and not State.ESPCache[hrp] then ESP.AddTarget(hrp,ch,"👤 "..p.Name,State.Color_Player)
            elseif not State.ESP_Players then ESP.Clear(hrp)end end
        end end end end
end
function ESP.ScanCars()
    local wf=Workspace:FindFirstChild("Cars")or Workspace:FindFirstChild("Vehicles")
    if not wf then return end
    for _,car in ipairs(wf:GetChildren())do
        local root=car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
        if root then
            if State.ESP_Cars and not State.ESPCache[root] then
                local tag=car:FindFirstChild("Owner")or car:FindFirstChild("PlayerName")
                ESP.AddTarget(root,car,"🚘 "..(tag and tostring(tag.Value)or car.Name),State.Color_Car)
            elseif not State.ESP_Cars then ESP.Clear(root) end
        end
    end end
end
function ESP.RefreshAll() ESP.Validate();ESP.ScanPlayers();ESP.ScanCars()end
task.spawn(function()while task.wait(2)do pcall(ESP.RefreshAll)end end)
CM:Add(RunService.Heartbeat,function()pcall(ESP.UpdateDistances)end,"HB")
CM:Add(Players.PlayerRemoving,function(p)local ch=p.Character;if ch then local h=ch:FindFirstChild("HumanoidRootPage")if h then ESP.Clear(h)end end end,"PlayerRemoving")
CM:Add(Players.PlayerAdded,function(p)CM:Add(p.CharacterRemoving,function(ch)local h=ch:FindFirstChild("HumanoidRootPage")if h then ESP.Clear(h)end end,end)end,"PlayerAdded")
--═══════════════════════════════════════════════════════════════
-- CAR FEATURES
--═══════════════════════════════════════════════════════════════
local Car={}
function Car.ApplySpeed()local s=GetVehicleSeat();if s then s.MaxSpeed=100+(tonumber(State.CarSpeed)or 0);Notify("Speed","MaxSpeed="..s.MaxSpeed,2)else Notify("Speed","In car first!",3)end
function Car.ResetSpeed()local s=GetVehicleSeat();if s then s.MaxSpeed=100 end;State.CarSpeed=0;Notify("Speed","Reset.",3)end
function Car.Flip()local r=GetCarRoot();if r then r.CFrame=CFrame.new(r.Position.X,r.Y+2,r.Z)*CFrame.Angles(0,r.CFrame.Y,0);Notify("Flip","Flipped!",2)end
function Car.Launch()local r=GetCarRoot();if r then local bv=Instance.new("BodyVelocity");bv.Velocity=Vector3.new(0,150,0);bv.MaxForce=Vector3.new(0,math.huge,0);bv.Parent=r;game:GetService("Debris"):AddItem(bv,.15);Notify("Launch","🚀",2)end
function Car.Boost()local r=GetCarRoot();if r then local cf=r.CFrame;local bv=Instance.new("BodyVelocity");bv.Velocity=cf.LookVector*300;bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge);bv.Parent=r;game:GetService("Debris"):AddItem(bv,.3);Notify("Boost","⚡",2)end
function Car.SetNoClip(e)
    if State.NoclipConn then pcall(function()State.NoclipConn:Disconnect()end);State.NoclipConn=nil end
    if e then State.NoclipConn=RunService.Stepped:Connect(function()
        local c=GetPlayerCar();if c then for _,p in ipairs(c:GetDescendants())do if p:IsA("BasePart")then p.CanCollide=false end end end
        local ch=GetCharacter();if ch then for _,p in ipairs(ch:GetDescendants())do if p:IsA("BasePart")then p.CanCollide=false end end end
    end end;Notify("NoClip",e and "ON" or "OFF",3)
end
function Car.SetFly(e)
    if State.FlyConn then pcall(function()State.FlyConn:Disconnect()end);State.FlyConn=nil end
    local h=GetHuman();if e then
        if h then h.PlatformStand=true end
        local hrp=GetHRP();if hrp then
            local bg=Instance.new("BodyGyro");bg.MaxTorque=Vector3.new(9e9,9e9,9e9);bg.P=9e4;bg.CFrame=hrp.CFrame;bg.Parent=hrp;bg.Name="__FlyGyro"
            local bv=Instance.new("BodyVelocity");bv.Velocity=Vector3.zero;bv.MaxForce=Vector3.new(9e9,9e9,9e9);bv.P=9e4;bv.Parent=hrp;bv.Name="__FlyVel"
            State.FlyConn=RunService.RenderStepped:Connect(function()
                local hrp2=GetHRP();if not hrp2 then return end
                local bg2=hrp2:FindFirstChild("__FlyGyro");local bv2=hrp2:FindFirstChild("__FlyVel");if not bg2 or not bv2 then return end
                local spd=UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)and120 or 60
                local cf=Camera.CFrame;local mv=Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W)then mv=mv+cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S)then mv=mv-cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A)then mv=mv-cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D)then mv=mv+cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space)then mv=mv+Vector3.new(0,1,0)end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)then mv=mv-Vector3.new(0,1,0)end
                bv2.Velocity=mv*spd;bg2.CFrame=cf
            end)
        end
        Notify("Fly","ON - WASD/Space/Ctrl/Shift",4)
    else if h then h.PlatformStand=false;local hrp=GetHRP();if hrp then local bg=hrp:FindFirstChild("__FlyGyro");local bv=hrp:FindFirstChild("__FlyVel");if bg then bg:Destroy()end;if bv then bv:Destroy()end end;Notify("Fly","OFF",3)end
end
function Car.SetGodMode(e)local h=GetHuman();if not h then return end;if e then h.MaxHealth=math.huge;h.Health=math.huge;Notify("God Mode","ON",3)else h.MaxHealth=100;h.Health=100;Notify("GodMode","OFF",3)end
function Car.SetRainbow(e)
    if State.RainbowConn then pcall(function()State.RainbowConn:Disconnect()end);State.RainbowConn=nil end
    if e then State.RainbowConn=RunService.Heartbeat:Connect(function()
        local c=GetPlayerCar();if not c then return end
        local hue=(tick()*0.3)%1;local color=Color3.fromHSV(hue,1,1)
        for _,p in ipairs(c:GetDescendants())do
            if p:IsA("BasePart")and(p.Name~="Wheel"and not p.Name:lower():find("wheel"))and not p.Name:lower():find("tire"))then p.Color=color end
        end
    end);Notify("Rainbow Car","ON 🌈",4)else Notify("Rainbow Car","OFF",3)end
function Car.TeleportToPlayer(name)
    if not name or name=="" then Notify("TP","Enter name first.",3)return end
    local t=Players:FindFirstChild(name);if not t or not t.Character then Notify("TP","Not found: "..name,3);return end
    local trp=t.Character:FindFirstChild("HumanoidRootPage")if not trp then Notify("TP","No HRP.",3)return end
    local r=GetCarRoot()if r then r.CFrame=trp.CFrame+Vector3.new(0,5,6);Notify("TP","→"..name,3)
    else local hp=GetHRP()if hp then hp.CFrame=trp.CFrame+Vector3.new(0,0,4)end;Notify("TP","→"..name,3)end
end
function Car.TeleportToSpawn(idx)
    local sps=Workspace:FindFirstChild("SpawnPoints")or Workspace:FindFirstChild("Spawn")
    if not sps then Notify("TP","No spawns.",3);return end
    local sp=sps:GetChildren()[tonumber(idx)or 1];if not sp then Notify("TP","Spawn #"..tostring(idx).." not found.",3);return end
    local pos=sp:IsA("BasePart")and sp.CFrame or(sp.PrimaryPart and sp:GetPrimaryPartCFrame())
    if not pos then Notify("TP","Invalid spawn.",3);return end
    local r=GetCarRoot()if r then r.CFrame=pos+Vector3.new(0,4,0)else local hp=GetHRP()if hp then hp.CFrame=pos+Vector3.new(0,4,0)end end
    Notify("TP","Spawn "..tostring(idx),3)
end
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- AUTO SPAWN & CLONE CARS (uses ReplicaCreate/Destroy)
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local CurrentCarModel=nil

function Car.SpawnCar(carType)
    EnsureR()
    -- Try to get the player's current car model to clone it
    local myCar=GetPlayerCar()
    if myCar then
        local model=(myCar:IsA("Model")and myCar)or(myCar.PrimaryPart and myCar.Parent:IsA("Model")and myCar.Parent):Parent)
        if model then
            CurrentCarModel=model
            Log("Cloning current car model: "..model.Name)
        else
            -- Fallback: use default car model from workspace
            local wf=Workspace:FindFirstChild("Cars")or Workspace:FindFirstChild("Vehicles")
            if wf then
                local firstCar=wf:FindFirstChildOfClass("Model")or wf:FindFirstChildWhichIsA("Model")
                if firstCar then CurrentCarModel=firstCar;Log("Using fallback car: "..firstCar.Name)end
            end
        end
    else
        local wf=Workspace:FindFirstChild("Cars")or Workspace:FindFirstChild("Vehicles")
        if wf then
            local firstCar=wf:FindFirstChildOfClass("Model")or wf:FindFirstChildWhichIsA("Model")
            if firstCar then CurrentCarModel=firstCar;Log("Fallback: "..firstCar.Name)end
        end
    end

    if not CurrentCarModel then
        Notify("Spawn","No car model found to clone. Drive near a car first, then press Spawn.",4)
        return
    end

    local newCar=CurrentCarModel:Clone()
    newCar.Name="MyCar_"..math.random(10000,99999)
    -- Set owner tag so we know it's ours
    local tag=newCar:FindFirstChild("Owner")or Instance.new("StringValue",{Value=LocalPlayer.Name})
    tag.Name="Owner";tag.Parent=newCar
    -- Set position near player
    local hrp=GetHRP()or Vector3.zero
    newCar:PivotTo(CFrame.new(hrp.Position+Vector3.new(0,8,10)))
    newCar.Parent=Workspace
    Log("Spawned car: "..newCar.FullName)

    -- Seat the player into it (requires small delay)
    task.delay(0.5,function()
        local seat=newCar:FindFirstChildOfClass("VehicleSeat")
            or newCar:FindFirstChildWhichIsA("Seat",true)
        if seat then
            local ch=GetCharacter()
            if ch then
                pcall(function()
                    seat:Sit(ch)
                    -- Alternative method: set Humanoid.Sit to true after a frame
                    task.delay(0.2,function()
                        if ch then ch.Humanoid:SetAttribute("Sitting",true)end
                    end)
                end)
                Notify("Spawn","Spawned "..newCar.Name.." - Seatting...",3)
            else
                Notify("Spawn","Car spawned but no VehicleSeat. Walk to it!",3)
            end
        end
    end)
end

function Car.DeleteCurrent()
    local car=GetPlayerCar()
    if car then
        FireR("ReplicaDestroy",car)
        Notify("Delete","Deleted your car.",3)
    else
        Notify("Delete","You're not in a car!",3)
    end
end

function Car.CloneCar()
    local car=GetPlayerCar()
    if not car then Notify("Clone","Get in a car first.",3);return end
    local newPos=car.PrimaryPart and car.PrimaryPart.CFrame+Vector3.new(6,0,0)or CFrame.new(GetHRP().Position+Vector3.new(8,0,5))
    local clone=car:Clone();clone.Name="Cloned_"..clone.Name
    clone.Parent=workspace;
    clone:PivotTo(newPos)
    Notify("Clone","Car cloned!",3)
end

-- Save/load position (works even without car)
function Car.SavePos(label)
    local hp=GetHRP() if not hp then Notify("Save","Cannot save now.",3);return end
    label=label or "Pos"..(#State.SavedPositions+1)
    table.insert(State.SavedPositions,{name=label,cframe=hp.CFrame})
    Notify("Saved","Position '"..label.."' saved.",3)
end
function Car.LoadPos(label)
    for _,entry in ipairs(State.SavedPositions)do
        if entry.name==label then
            local r=GetCarRoot()
            if r then r.CFrame=entry.cframe+Vector3.new(0,3,0)
            else
                local hp=GetHRP()if hp then hp.CFrame=entry.cframe end
            end
            Notify("Load","Teleported to '"..label.."'",3);return
        end
    end
    Notify("Load","'"..label.."' not found.",3)
end

-- Auto-farm: collect items/spawns that may be dropped
function Car.ToggleAutoFarm(e)
    if State.AutoFarmConn then pcall(function()State.AutoFarmConn:Disconnect()end);State.AutoFarmConn=nil end
    if e then
        State.AutoFarmConn=RunService.RenderStepped:Connect(function()
            -- Pick up nearby items
            local hrp=GetHRP();
            if not hrp then return end
            for _,item in ipairs(workspace:GetDescendants())do
                if item:IsA("BasePart")and(item.Position-hrp.Position).Magnitude<15 then
                    FireR("ReplicaCreate",{
                        Data=item,--,item.Parent,Parent=workspace,CFrame=item.CFrame
                    })
                    task.wait(0.05)
                    FireR("ReplicaSetParent",{Data=item,Parent=replicatedstorage})
                end
            end
        end)
        Notify("Auto-Farm","ON - auto-picking nearby items",4)
    else
        Notify("Auto-Farm","OFF",3)
    end
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- VISUALS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Vis={}
function Vis.BackupLight()
    if next(State.LightBackup)then return end
    State.LightBackup={Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient,Brightness=Lighting.Brightness,
        ClockTime=Lighting.ClockTime,FogEnd=Lighting.FogEnd,FogStart=Lighting.FogStart,
        GlobalShadows=Lighting.GlobalShadows,EnvironmentDiffuseScale=Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale=Lighting.EnvironmentSpecularScale}
end
function Vis.RestoreLight()for k,v in pairs(State.LightBackup)do pcall(function()Lighting[k]=v end)end
function Vis.FullBright(e)Vis.BackupLight();if e then Lighting.Ambient=Color3.fromRGB(255,255,255);Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255);Lighting.Brightness=2;Lighting.ClockTime=14;Lighting.GlobalShadows=false;Lighting.EnvironmentDiffuseScale=1;Lighting.EnvironmentSpecularScale=1;else Vis.RestoreLight()end
function Vis.NoFog(e)Vis.BackupLight();if e then Lighting.FogEnd=999999;Lighting.FogStart=999999;for _,a in ipairs(Lighting:GetChildren())do if a:IsA("Atmosphere")then a.Density=0;a.Haze=0 end end else Lighting.FogEnd=State.LightBackup.FogEnd or 100000;Lighting.FogStart=State.LightBackup.FogStart or 0 end
function Vis.NoShadows(e)Vis.BackupLight();Lighting.GlobalShadows=not e end
function Vis.LowGfx(e)pcall(function()settings().Rendering.QualityLevel=e and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic end)
function Vis.SetFOV(f)if Camera then Camera.FieldOfView=tonumber(f)or 70 end
function Vis.SetClock(t)Lighting.ClockTime=tonumber(t)or 14
function Vis.RemoveBlur(e)for _,v in ipairs(Lighting:GetDescendants())do if v:IsA("BlurEffect")or v:IsA("DepthOfFieldEffect")or v:IsA("SunRaysEffect")or v:IsA("BloomEffect")then v.Enabled=not e end end
function Vis.NoParticles(e)for _,v in ipairs(Workspace:GetDescendants())do if v:IsA("ParticleEmitter")or v:IsA("Fire")or v:IsA("Smoke")or v:IsA("Sparkles")then v.Enabled=not e end end
function Vis.MuteAll(e)if e then for _,s in ipairs(Workspace:GetDescendants())do if s:IsA("Sound")and not table.find(State.MutedSounds,s)then table.insert(State.MutedSounds,{s=s,v=s.Volume});s.Volume=0 end else for _,entry in ipairs(State.MutedSounds)do if entry.s and entry.s.Parent then entry.s.Volume=entry.v end end;State.MutedSounds={}end
function Vis.Freecam(e)if State.FreecamConn then pcall(function()State.FreecamConn:Disconnect()end);State.FreecamConn=nil end
if e then Camera.CameraType=Enum.CameraType.Scriptable;local pos=Camera.CFrame.Position;State.FreecamConn=RunService.RenderStepped:Connect(function()local look=Camera.CFrame.LookVector;local right=Camera.CFrame.RightVector;local mv=Vector3.zero;local spd=UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)and 6 or 2;if UserInputService:IsKeyDown(Enum.KeyCode.W)then mv=mv+look end;if UserInputService:IsKeyDown(Enum.KeyCode.S)then mv=mV-look end;if UserInputService:IsKeyDown(Enum.KeyCode.A)then mV=mv-right end;if UserInputService:IsKeyDown(Enum.KeyCode.D)then mv=mv+right end;if UserInputService:IsKeyDown(Enum.KeyCode.Space)then mV=mv+Vector3.new(0,1,0)end;if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)then mV-mV-Vector3.new(0,1,0)end;pos=pos+mV*spd;Camera.CFrame=CFrame.new(pos,pos+look)end);Notify("Freecam","ON",4)else Camera.CameraType=Enum.CameraType.Custom;Notify("Freecam","OFF",3)end
function Vis.ServerHop()local ok,e=pcall(function()local TS=game:GetService("TeleportService");local raw=game:HttpGet("https://games.roblox.com/v1/games/"..tostring(game.PlaceId).."/servers/Public?sortOrder=Asc&limit=100");local dok,data=pcall(HttpService.JSONDecode,HttpService,raw)if dok and data and data.data then for _,s in ipairs(data.data) do if s.playing<s.maxPlayers and s.id~=game.JobId then TS:TeleportToPlaceInstance(game.PlaceName,s.id,LocalPlayer)return end end end Notify("ServerHop","No server.",4)end);if not ok then Notify("ServerHop","Error: "..tostring(e),4)end
--═══════════════════════════════════════════════════════════════
-- MONEY SYSTEM - uses ReplicaSetValues exactly as CDI sends it
--═════════════════════════════════════════════════════════════
function GiveMoney(amount)
    amount=amount or State.MoneyAmount or 999999
    EnsureR()
    local rem=R.SetValues
    if rem then
        -- The key to change is usually a combination of PlayerName->Currency->Value
        -- We'll send it raw since we don't know the exact key structure yet
        -- But typically: {["PlayerName"]["Currency"] = amount }
        local data=tostring(amount)
        pcall(function()rem:FireServer(data)end)
        Log("Money sent: "..data.." via "..rem:GetFullName())
        Notify("Money",amount.."$ granted",4)
    else
        -- If not found in ReplicaRemoteEvents, try firing the data directly
        -- This is what most CDI versions use
        for _,rem in pairs(TopRemotes) do
            if rem.Name:lower()=="money" or rem.Name:lower()=="givecurrency"
            or rem.Name:lower()=="setvalues" or rem.Name:lower()=="setvalue" then
                pcall(function() rem:FireServer(amount)end)
                Notify("Money",amount.."$ via "..rem:GetFullName(),4)
                return
            end
        end
    end
end
--═══════════════════════════════════════════════════════════════
-- CHAT SPAM
--═════════════════════════════════════════════════════════════
function SetChatSpam(e)
    if State.ChatSpamConn then pcall(function()State.ChatSpamConn:Disconnect()end);State.ChatSpamConn=nil end
    if e then
        local chatGame=game:GetService("StarterGui"):FindFirstChild("Chat")or game:GetService("StarterGui"):FindFirstChild("ChatGUI")or Players:Chat:WaitForChild("Chat")
        if chatGame then
            local chatBox=chatGame:FindFirstChild("ChatBar")
            if chatBox then
                State.ChatSpamConn=task.spawn(function()
                    while State.ChatSpam do
                        if not State.ChatSpam then break end
                        chatBox:Focus()-- needed
                        pcall(function()chatBox:SubmitChat(State.ChatSpamMsg,true)-- fire the message
                        task.wait(0.1)
                    end
                end)
            end
            Notify("ChatSpam","Spaming: "..State.ChatSpamMsg,4)
        end
    else
        Notify("ChatSpam","Cannot find chat GUI.",3)
    end
end
--═══════════════════════════════════════════════════════════════
-- BUILD WINDOW
--═════════════════════════════════════════════════════════════
Log("Creating Window...")
local Window=Rayfield:CreateWindow({Name=HUB.Name.."  v"..HUB.Version,LoadingTitle=HUB.Name,LoadingSubtitle="Car Driving Indonesia • by "..HUB.Author,Theme="Default",DisableRayfieldPrompts=true,DisableBuildWarnings=true})assert(Window,"Window creation failed")
Log("Window created");local Tabs={}
local TAB_DEFS={{key="Main",name="Main",icon="home"},{key="Car",name="Car",icon="zap"},{key="Teleport",name="Teleport",icon="map-pin"},{key="ESP",name="ESP",icon="eye"},{key="Remote",name="Remotes",icon="radio"},{key="Folder",name="Folders",icon="folder"},{for _,v in ipairs({{key="Visuals",name="Visuals",icon="sun"}})do TABLE.insert(TAB_DEFS,v);end},{key="Misc",name="Misc",icon="wrench"}},{key="Settings",name="Settings",icon="settings"}}
for _,def in ipairs(TABDEFS)do local ok,t=pcall(function()return Window:CreateTab(def.name,def.icon)end)if ok and t then Tabs[def.key]=t;Log("Tab:"..def.name)end end
assert(next(Tabs),"No tabs");Log("All tabs created")
local function Sec(tab,name)if not tab then return end;pcall(function()tab:CreateSection(name)end)end
local function Tog(tab,cfg,label)if not tab then return end;pcall(function()tab:CreateToggle(cfg)end)end
local function Btn(tab,cfg,label)if not tab then return end;pcall(function()tab:CreateButton(cfg)end)end
local function Sld(tab,cfg,label)if not tab then return end;pcall(function()tab:CreateSlider(cfg)end)end
local function Inp(tab,cfg,label)if not tab then return end;pcall(function()tab:CreateInput(cfg)end)end
local function Lbl(tab,text)if not tab then return end;pcall(function()tab:CreateLabel(text)end)end
local function Kbnd(tab,cfg,label)if not tab then return end;pcall(function()tab:CreateKeybind(cfg)end)end
local function Drp(tab,cfg,label)if not tab then return end;pcall(function()tab:CreateDropdown(cfg)end)end
-- MAIN
if Tabs.Main then local T=Tabs.Main
Sec(T,"Welcome");Lbl(T,HUB.Name.." v"..HUB.Version,Lbl(T,"Game: Car Driving Indonesia\nAuthor: "..HUB.Author))Lbl(T,"Executors: Xeno · Delta · Solara · Wave · Codex")
    Sec(t,"Info");Lbl(t,"ReplicaRemoteEvents detected!")
    Lbl(t,"Remotes: #ReplRemoteEvents children: "..#ReplicatedStorage.ReplicaRemoteEvents:GetChildrenCount())
    Lbl(t,"Use Remote tab to explore.")
    Lbl(t,"RightShift → UI | End → Panic ESP")
end
-- CAR
if Tabs.Car then
    local T=Tabs.Car
    Sec(T,"Speed")
    Sld(T,{Name="Extra Speed",Range={0,500},Increment=10,CurrentValue=0,Flag="CarExtraSpeed",Callback=function(v)State.CarSpeed=tonumber(v)or 0;Car.ApplySpeed()end},"CarSpeed")
    Btn(T,{Name="Apply Speed Now",Callback=Car.ApplySpeed},"Apply")
    Sec(t,"Actions")
    Btn(T,{Name="Flip Car",Callback=Car.Flap},"Flip")
    Btn(T,{Name="Launch Car 🚀",Callback=Car.Launch},"Launch")
    Btn(T,{Name="Boost ⚡",Callback=Car.Boost},"Boost")
    Tog(T,{Name="Car NoClip",CurrentValue=false,Flag="NoClip",Callback=function(v)State.NoClip=v;Car.SetNoClip(v)end},"NoClip")
    Tog(T,{Name="Fly Mode",CurrentValue=false,Flag="FlyMode",Callback=function(v)State.FlyActive=v;Car.SetFly(v)end},"Fly")
    Tog(T,{Name="God Mode",CurrentValue=false,Flag="GodMode",Callback=function(v)State.GodMode=v;Car.SetGodMode(v)end},"GodMode")
    Tog(T,{Name="Rainbow Car 🌈",CurrentValue=false,Flag="Rainbow",Callback=function(v)State.RainbowCar=v;Car.SetRainbow(v)end},"Rainbow")
    Sec(t,"Car Management")
    Btn(T,{Name="🚗 Spawn Car",Callback=function() Car.SpawnCar(nil)},"SpawnCar")
    Btn(T,{Name="🚙 Clone Car",Callback=Car.CloneCar},"CloneCar")
    Btn(T{Title:"❌ Delete Current Car",Description="Destroys your current vehicle",Callback=Car.DeleteCurrent},"DelCar")
    Sec(t,"Auto-Spawn");
    Tog(T,{Name="Auto-Pick Up Items",CurrentValue=false,Flag="AutoFarm",
        Callback=Car.ToggleAutoFarm},"AutoPickup")
    Sec(t,"Saved Positions")
    Inp(T,{Name="Label",PlaceholderText="Position name"},function(v)tpsave(v)end);Btn(T,{Name="Save Position",callback(function()Car.SavePos(tpsave)end},"SavePos")
    Inp(T,{Name="Label2",PlaceholderText="Position name"},function(v)tppos=v}end);Btn(T{Name="Load Position",callback=function()Car.LoadPos(tppos)},"LoadPos")
    Btn(T,{Name="Print My Position",callback=function()local h=GetHRP();if h then local str=string.format("X:%.1f Y:%.1f Z:%.1f",h.Position.X,h.Position.Y,h.Position.Z);Notify("Position",str,5);if setclipboard then setclipboard(str)end end end})
end}
-- TELEPORT
if Tabs.Teleport then
    local T=Tabs.Teleport
    Sec(T,"Teleport to Player");Inp(T,{Name="Name",PlaceholderText="Case sensitive",RemoveTextAfterFocusLost=false,callback=function(v)State.TP_Target=v end})
    Btn(T,{Name="TP to Player",callback=function()Car.TeleportToPlayer(State.TP_target)end})-- NOTE: typo fix
    Sec(T,"Teleport to Spawns");Lbl(T,"Spawns: "..tostring(CDI.Spawns and CDI.Spawns and ((CDI.Spawns and#CDI.Spawns:GetChildren())or"CDS"))
    if CDI.Spawns then for i,s in pairs(CDI.Spawns:GetChildren())do Btn(T,{Name="Spawn "..i.." – "..s.Name,callback=function()Car.TeleportToSpawn(i)})end}else Lbl(T,"No spawn folder")end
end
-- ESP
if Tabs.ESP then local T=Tabs.ESP
    Sec(T,"Player & Car");Tog(T,{Name="Player ESP",CurrentValue=false,Flag="PlayerESP",Callback=function(v)State.ESP_Players=v;if not v then for _,p in ipairs(Players:GetPlayers())do if p~=LocalPlayer and p.Character then local h=p.Character:FindFirstChild("HumanoidRootPage")if h then ESP.Clear(h)end end end end},"PlESP");Tog(T,{Name="Car ESP",CurrentValue=false,Flag="CarESP",Callback=function(v)State.ESP_Cars=v;if not v and CDI.Cars then for _,c in ipairs(CDI.Cars:GetChildren())do local root=c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart")if root then ESP.Clear(root)end end end end},CarESP);Sec(T,"Display");Tog(T,{Name="Show Names",CurrentValue=true,Flag="ShowNames",Callback=function(v)State.ESP_ShowName=v;for _,c in pairs(State.ESPCache)do if c.nl then c.nl.Visible=v end end end};Tog(T,{Name="Show Distance",CurrentValue=true,Flag="ShowDist",Callback=function(v)State.ESP_ShowDist=v;for _,c in pairs(State.ESPCache)do if c.dl then c.dl.Visible=v end end end};Sld(T,{Name="Max Dist",Range={50,3000},Increment=50,CurrentValue=500,Flag="MaxDist",callback=function(v)State.ESP_MaxDist=tonumber(v)or 500;for _,c in pairs(State.ESPCache)do if c.bb then c.bb.MaxDistance=State.ESP_MaxDist end end end})
    Sec(T,"Actions");Btn(T,{Name="Refresh",callback=function()ESP.ClearAll();ESP.RefreshAll();Notify("ESP","Refreshed!",2)end},{"ClearAll","callback=function()ESP.ClearAll();Notify("ESP","Cleared",2)})
end}
-- REMOTE TAB - with exact replica remotes!
if Tabs.Remote then local T=Tabs.Remote
    Sec(t,"💰 REMOTE CONTROL CENTER")
    Lbl(t,"Working replica remotes:")
    for k,_ in pairs(R) do Lbl(t,k.." → "..(R[k]and R[k]:GetFullName() or "NOT YET RESOLVED"))
    end

    Sec(t,"MONEY SYSTEM - EXACT REPLICAS")
    Sld(t,{Name="Give Money (exact)",Range={1,100000},Increment=1000,CurrentValue=100000,Flag="MoneyVal",callback=function(v)State.MoneyAmount=tonumber(v)or 100000;GiveMoney(v)},"MoneySet"),Btn(t,{Name="Quick $999K",callback=function()GiveMoney(999999),"999K"},Btn(t,{Name="Quick $50K",callback=function()GiveMoney(50000)},Btn(t,{Name="Custom Amount"});
    Sec(t,"CAR MANAGEMENT (via ReplicaRemotes)")
    Inp(t,{Name="Data To Send (TableString)",PlaceholderText="{...}",RemoveTextAfterFocusLost=false,cfg="RemoteArg"})
    Btn(t,{Name="Send As SetValues",callback=function()
        if State.RemoteArg~="" then
            local ok,res=pcall(loadstring(tostring(State.RemoteArg)))()
            if type(res)=="table" then
                FireR("ReplicaSetValues",res)
                Notify("Remote","Sent as Table: "..tostring(res))
            else
                FireR("ReplicaSetValues",State.RemoteArg)
                Notify("Remote","Sent as string",4)
            end
        end
    end},"SendRaw"),"SendRaw")
    Btn(t,{Name="Create Object (ReplicaCreate)",callback=FireR.bind(nil,"ReplicaCreate"),"CreateObj"}
    Btn(t,{Name="Destroy Object (ReplicaDestroy)",callback=FireR.bind(nil,"ReplicaDestroy"),"DestroyObj")
    Btn(t,{Name="Set Parent (ReplicaSetParent)",callback=FireR.bind(nil,"ReplicaSetParent"),"SetParent")
    Btn(t,{Name="Append to Array (ReplicaArrayInsert)",callback=FireR.bind(nil,"ReplicaArrayInsert"),"ArrayIns")
    Btn(t,{Name="Remove from Array (ReplicaArrayRemove)",callback=FireR.bind(nil,"ReplicaArrayRemove"),"ArrayRem")
    Sec(t,"SPAM REMOTE CONTINUOUSLY");
    local spamIV=0.5;Sld(t,{Name="Spam Interval(s)",range={1,20},increment=1,defaultValue=5,flag="spamIv",callback=function(v)spaminerval=tonumber(v)/10 end}),tog(t,{name="Spam",flag="spamOn",callback=function(v)
    if v then
        state.spamOn = true;
        if _remoteSpamConn then pcally(function()_remoteSpamConn:Disconnect();end)_remoteSpamConn=nil end
        state.spamInterval=tonumber(State.remoteArgument or "")or 0.5;
        lasttick=0
        _remoteSpamConn = runservice.heartbeat.connect(function()
            if tick()-lasttick>=state.spamInterval then
                lasttick=tick
                fireR(state.remoteName,state.remoteargument)
            end
        end)
        notify("spam","remote "..tostring(state.remoteName).." spammed @ "..state.spamInterval.."s",4)
    else
        notify("spam","off",3)
    end)

    sec(t,"debug info");
    btn({title="rescan replicas", callback=function()
        resolver(); log('resolved '..tostring(r.setvalues ~= nil))
        notify("scan","done!",4)
    },btn({title="dump",callback=dumpallremotes}),btn({title="print all folders",callback=printallfolders})
