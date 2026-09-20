--═══════════════════════════════════════════════════════════════════════════════
-- X0DEC04T Tools - Visual Avatar Changer v1.9.0 [Fluent UI]
-- VISUAL ONLY | Catalog Loader | Exact Korblox IDs (139607718 / 139607673)
--═══════════════════════════════════════════════════════════════════════════════

local Players            = game:GetService("Players")
local InsertService      = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local CoreGui            = game:GetService("CoreGui")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local ContentProvider    = game:GetService("ContentProvider")

local LocalPlayer = Players.LocalPlayer

local TOOL_KEY = "__X0DEC04T_Avatar_v19"
if _G[TOOL_KEY] then
    local prev = _G[TOOL_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[TOOL_KEY] = nil
    task.wait(0.25)
end

--------------------------------------------------------------------------------
-- FLUENT + ADDONS
--------------------------------------------------------------------------------
local Fluent, SaveManager, InterfaceManager

local ok1, r1 = pcall(function()
    return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
end)
if not ok1 or not r1 then error("[X0DEC04T] Fluent load failed: " .. tostring(r1)) end
Fluent = r1

pcall(function()
    SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
end)
pcall(function()
    InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
end)

local TOOL = {
    Name    = "X0DEC04T Avatar",
    Version = "1.9.0",
    LogoId  = "rbxassetid://85855925276969",
}

--------------------------------------------------------------------------------
-- UTILITIES
--------------------------------------------------------------------------------
local CM = { _list = {} }
function CM:Add(sig, cb)
    if not sig then return end
    local s, conn = pcall(function() return sig:Connect(cb) end)
    if s and conn then table.insert(self._list, conn); return conn end
end
function CM:Cleanup()
    for _, c in ipairs(self._list) do pcall(function() c:Disconnect() end) end
    self._list = {}
end

local function GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end

local function Notif(t, c, d)
    pcall(function()
        Fluent:Notify({ Title = tostring(t), Content = tostring(c), Duration = tonumber(d) or 3 })
    end)
end

local function GetChar()
    return LocalPlayer.Character
end

local function GetHumanoid()
    local c = GetChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function IsR15()
    local h = GetHumanoid()
    return h and h.RigType == Enum.HumanoidRigType.R15
end

local function Log(m)
    print("[X0DEC04T Avatar] " .. tostring(m))
end

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------
local State = {
    SavedIds         = {},
    Instances        = {},

    Headless         = false,
    KorbloxRight     = false,
    KorbloxLeft      = false,

    FloatingLogo     = true,
    LogoGui          = nil,
    LogoImage        = nil,
    LogoSize         = 60,
    LogoTransparency = 0.1,
}

--------------------------------------------------------------------------------
-- KORBLOX EXACT ASSET IDs
--------------------------------------------------------------------------------
local KORBLOX_RIGHT_ID = 139607718
local KORBLOX_LEFT_ID  = 139607673

local _korbloxBackup = {} -- [part] = {MeshId, TextureID, Transparency}

--------------------------------------------------------------------------------
-- ID PARSER
--------------------------------------------------------------------------------
local function ParseId(input)
    if not input or input == "" then return nil end
    input = tostring(input):gsub("%s+", "")

    local urlId = input:match("roblox%.com/catalog/(%d+)")
              or input:match("roblox%.com/bundles/(%d+)")
              or input:match("roblox%.com/library/(%d+)")
              or input:match("roblox%.com/item/(%d+)")
              or input:match("roblox%.com/.+/catalog/(%d+)")
    if urlId then return tonumber(urlId) end

    local rbxId = input:match("rbxassetid://(%d+)")
    if rbxId then return tonumber(rbxId) end

    if input:match("^%d+$") then return tonumber(input) end

    local num = input:match("(%d+)")
    if num and #num >= 5 then return tonumber(num) end

    return nil
end

--------------------------------------------------------------------------------
-- ASSET TYPE MAP
--------------------------------------------------------------------------------
local ASSET_TYPE_MAP = {
    [2]  = "TShirt",  [8]  = "Hat",     [11] = "Shirt",   [12] = "Pants",
    [17] = "Head",    [18] = "Face",    [19] = "Gear",    [27] = "Torso",
    [28] = "RightArm",[29] = "LeftArm", [30] = "LeftLeg", [31] = "RightLeg",
    [41] = "Hair",    [42] = "FaceAccessory", [43] = "Neck", [44] = "Shoulder",
    [45] = "Front",   [46] = "Back",    [47] = "Waist",
    [64] = "TShirtAccessory", [65] = "ShirtAccessory", [66] = "PantsAccessory",
    [67] = "Jacket",  [68] = "Sweater", [69] = "Shorts",
    [70] = "LeftShoe",[71] = "RightShoe", [72] = "DressSkirt",
    [76] = "Eyebrow", [77] = "Eyelash",
}

local function GetAssetInfo(assetId)
    local info = nil
    pcall(function()
        info = MarketplaceService:GetProductInfo(assetId, Enum.InfoType.Asset)
    end)
    return info
end

--------------------------------------------------------------------------------
-- MULTI-METHOD ASSET LOADER
--------------------------------------------------------------------------------
local function LoadAssetModel(assetId)
    local assetStr = "rbxassetid://" .. tostring(assetId)
    local model = nil
    local method = "none"

    if typeof(GetObjects) == "function" or typeof(game.GetObjects) == "function" then
        local ok, res = pcall(function()
            if GetObjects then return GetObjects(assetStr) else return game:GetObjects(assetStr) end
        end)
        if ok and res then
            if typeof(res) == "table" and res[1] then model = res[1]; method = "GetObjects"
            elseif typeof(res) == "Instance" then model = res; method = "GetObjects" end
        end
    end

    if not model then
        local ok, res = pcall(function() return InsertService:LoadLocalAsset(assetStr) end)
        if ok and res then model = res; method = "LoadLocalAsset" end
    end

    if not model then
        local ok, res = pcall(function() return InsertService:LoadAsset(assetId) end)
        if ok and res then model = res; method = "LoadAsset" end
    end

    return model, method
end

--------------------------------------------------------------------------------
-- KORBLOX LEG ENGINE (DIRECT ASSET LOADING - ZERO OUTFIT DELETION)
--------------------------------------------------------------------------------
local function ApplyKorbloxSide(side, enable)
    local char = GetChar()
    if not char then return false end

    if not IsR15() then
        if enable then Notif("Korblox", "R15 rig required", 3) end
        return false
    end

    local legNames = (side == "Right") 
        and { "RightUpperLeg", "RightLowerLeg", "RightFoot" }
        or  { "LeftUpperLeg",  "LeftLowerLeg",  "LeftFoot" }

    -- Clean up previous modifications for this side
    for _, name in ipairs(legNames) do
        local part = char:FindFirstChild(name)
        if part then
            local b = _korbloxBackup[part]
            if b then
                pcall(function()
                    part.Transparency = b.Transparency
                    if part:IsA("MeshPart") then
                        part.MeshId = b.MeshId
                        part.TextureID = b.TextureID
                    end
                end)
            end
        end

        local overlayName = "X0_Korblox_" .. side .. "_" .. name
        local overlay = char:FindFirstChild(overlayName)
        if overlay then pcall(function() overlay:Destroy() end) end
    end

    if not enable then
        Log("Korblox " .. side .. " leg disabled")
        return true
    end

    local assetId = (side == "Right") and KORBLOX_RIGHT_ID or KORBLOX_LEFT_ID
    local model = LoadAssetModel(assetId)

    if not model then
        Log("Failed to load Korblox asset " .. assetId)
        return false
    end

    for _, name in ipairs(legNames) do
        local charPart = char:FindFirstChild(name)
        if charPart and charPart:IsA("BasePart") then
            if not _korbloxBackup[charPart] then
                _korbloxBackup[charPart] = {
                    Transparency = charPart.Transparency,
                    MeshId       = charPart:IsA("MeshPart") and charPart.MeshId or "",
                    TextureID    = charPart:IsA("MeshPart") and charPart.TextureID or "",
                }
            end

            local targetMeshPart = model:FindFirstChild(name, true)
            if targetMeshPart and targetMeshPart:IsA("MeshPart") then
                local meshId = targetMeshPart.MeshId
                local texId  = targetMeshPart.TextureID

                local directOk = false
                if charPart:IsA("MeshPart") then
                    pcall(function()
                        charPart.MeshId = meshId
                        charPart.TextureID = texId
                        charPart.Transparency = 0
                    end)
                    if charPart.MeshId == meshId then
                        directOk = true
                    end
                end

                -- Fallback if executor restricts writing MeshId property directly
                if not directOk then
                    charPart.Transparency = 1

                    local clone = targetMeshPart:Clone()
                    clone.Name = "X0_Korblox_" .. side .. "_" .. name
                    clone.CanCollide = false
                    clone.Massless = true
                    clone.Anchored = false
                    clone.CFrame = charPart.CFrame

                    for _, v in ipairs(clone:GetDescendants()) do
                        if v:IsA("JointInstance") or v:IsA("WeldConstraint") or v:IsA("Script") then
                            pcall(function() v:Destroy() end)
                        end
                    end

                    local weld = Instance.new("WeldConstraint")
                    weld.Part0 = charPart
                    weld.Part1 = clone
                    weld.Parent = clone

                    clone.Parent = char
                end
            end
        end
    end

    pcall(function() model:Destroy() end)
    Log("Korblox " .. side .. " leg enabled via asset " .. assetId)
    return true
end

local function ApplyKorbloxRight(enable)
    State.KorbloxRight = enable
    return ApplyKorbloxSide("Right", enable)
end

local function ApplyKorbloxLeft(enable)
    State.KorbloxLeft = enable
    return ApplyKorbloxSide("Left", enable)
end

local function ReapplyKorblox()
    if State.KorbloxRight then ApplyKorbloxSide("Right", true) end
    if State.KorbloxLeft  then ApplyKorbloxSide("Left",  true) end
end

--------------------------------------------------------------------------------
-- RESTORE DEFAULT AVATAR
--------------------------------------------------------------------------------
local function RestoreOriginalAvatar()
    local char = GetChar()

    if char then
        for _, child in ipairs(char:GetChildren()) do
            if child.Name:match("^X0_") or child:FindFirstChild("X0_Tag") then
                pcall(function() child:Destroy() end)
            end
        end
    end

    ApplyKorbloxSide("Right", false)
    ApplyKorbloxSide("Left", false)
    _korbloxBackup = {}

    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.Transparency = 0 end
            if part:IsA("Decal") then part.Transparency = 0 end
        end
    end

    State.SavedIds = {}
    State.Instances = {}
    State.Headless = false
    State.KorbloxRight = false
    State.KorbloxLeft = false

    Log("Avatar restored")
end

--------------------------------------------------------------------------------
-- INSTANCE TRACKING
--------------------------------------------------------------------------------
local function TrackInstance(assetId, inst)
    local key = tostring(assetId)
    if not State.Instances[key] then State.Instances[key] = {} end
    table.insert(State.Instances[key], inst)
end

local function DestroyTracked(assetId)
    local key = tostring(assetId)
    local list = State.Instances[key]
    if list then
        for _, inst in ipairs(list) do pcall(function() inst:Destroy() end) end
        State.Instances[key] = nil
    end
end

local function FindSaved(assetId)
    for i, entry in ipairs(State.SavedIds) do
        if entry.id == assetId then return i, entry end
    end
    return nil, nil
end

local function AddSaved(assetId, name, assetType)
    if FindSaved(assetId) then return end
    table.insert(State.SavedIds, { id = assetId, name = name or tostring(assetId), type = assetType or "Unknown" })
end

local function RemoveSaved(assetId)
    local idx = FindSaved(assetId)
    if idx then table.remove(State.SavedIds, idx) end
end

--------------------------------------------------------------------------------
-- SAFE ACCESSORY ATTACHMENT
--------------------------------------------------------------------------------
local function AttachAccessoryManually(char, accessory)
    local handle = accessory:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then return false end

    local att = handle:FindFirstChildOfClass("Attachment")
    local targetPart = char:FindFirstChild("Head")
    local targetAtt = nil

    if att then
        for _, p in ipairs(char:GetChildren()) do
            if p:IsA("BasePart") then
                local match = p:FindFirstChild(att.Name)
                if match then
                    targetPart = p
                    targetAtt = match
                    break
                end
            end
        end
    end

    if targetAtt and att then
        handle.CFrame = targetAtt.WorldCFrame * att.CFrame:Inverse()
    elseif targetPart then
        handle.CFrame = targetPart.CFrame
    end

    handle.CanCollide = false
    handle.Massless = true

    local weld = Instance.new("WeldConstraint")
    weld.Name = "X0_Weld"
    weld.Part0 = targetPart
    weld.Part1 = handle
    weld.Parent = handle

    accessory.Parent = char
    return true
end

local function AddAccessorySafe(model, assetId)
    local char = GetChar()
    local hum  = GetHumanoid()
    if not char or not hum then return false end

    local accessory = model
    if not (model:IsA("Accessory") or model:IsA("Accoutrement")) then
        accessory = model:FindFirstChildOfClass("Accessory") or model:FindFirstChildWhichIsA("Accoutrement")
        if not accessory then
            for _, d in ipairs(model:GetDescendants()) do
                if d:IsA("Accessory") or d:IsA("Accoutrement") then
                    accessory = d
                    break
                end
            end
        end
    end

    if not accessory then return false end

    local acc = accessory:Clone()
    acc.Name = "X0_Acc_" .. tostring(assetId)

    local tag = Instance.new("BoolValue")
    tag.Name = "X0_Tag"
    tag.Parent = acc

    for _, v in ipairs(acc:GetDescendants()) do
        if v:IsA("Weld") or v:IsA("WeldConstraint") or v:IsA("ManualWeld") or v:IsA("Glue") or v:IsA("TouchTransmitter") then
            pcall(function() v:Destroy() end)
        end
    end

    local ok = pcall(function() hum:AddAccessory(acc) end)

    if not ok or acc.Parent ~= char then
        ok = AttachAccessoryManually(char, acc)
    end

    if ok then
        TrackInstance(assetId, acc)
    end

    pcall(function() model:Destroy() end)
    return ok
end

--------------------------------------------------------------------------------
-- APPLY METHODS
--------------------------------------------------------------------------------
local function ApplyClothing(assetId, assetType, assetName)
    local char = GetChar()
    if not char then return false, "No character" end

    DestroyTracked(assetId)

    local className, propName
    if assetType == "Shirt" then className = "Shirt"; propName = "ShirtTemplate"
    elseif assetType == "Pants" then className = "Pants"; propName = "PantsTemplate"
    elseif assetType == "TShirt" then className = "ShirtGraphic"; propName = "Graphic"
    else return false, "Unknown clothing" end

    for _, c in ipairs(char:GetChildren()) do
        if c:IsA(className) then pcall(function() c:Destroy() end) end
    end

    local obj = Instance.new(className)
    obj.Name = "X0_" .. className
    obj[propName] = "rbxassetid://" .. tostring(assetId)
    obj.Parent = char
    TrackInstance(assetId, obj)
    return true
end

local function ApplyFace(assetId, assetName)
    local char = GetChar()
    if not char then return false, "No character" end
    local head = char:FindFirstChild("Head")
    if not head then return false, "No head" end

    DestroyTracked(assetId)

    local face = head:FindFirstChild("face") or head:FindFirstChildOfClass("Decal")
    if not face then
        face = Instance.new("Decal")
        face.Name = "face"
        face.Face = Enum.NormalId.Front
        face.Parent = head
    end
    face.Texture = "rbxassetid://" .. tostring(assetId)
    TrackInstance(assetId, face)
    return true
end

local function ApplyBodyPartDescription(assetId, assetType)
    local hum = GetHumanoid()
    if not hum then return false, "No humanoid" end

    local ok = pcall(function()
        local desc = hum:GetAppliedDescription()
        if assetType == "Head" then desc.Head = assetId
        elseif assetType == "Torso" then desc.Torso = assetId
        elseif assetType == "RightArm" then desc.RightArm = assetId
        elseif assetType == "LeftArm" then desc.LeftArm = assetId
        elseif assetType == "LeftLeg" then desc.LeftLeg = assetId
        elseif assetType == "RightLeg" then desc.RightLeg = assetId
        elseif assetType == "Face" then desc.Face = assetId end
        pcall(function() hum:ApplyDescription(desc) end)
    end)
    return ok
end

local function ApplyAccessoryViaDescription(assetId)
    local hum = GetHumanoid()
    if not hum then return false end

    local ok = pcall(function()
        local desc = hum:GetAppliedDescription()
        local accessories = desc:GetAccessories(true)
        for _, a in ipairs(accessories) do
            if a.AssetId == assetId then return end
        end
        table.insert(accessories, {
            AssetId = assetId,
            AccessoryType = Enum.AccessoryType.Unknown,
            IsLayered = false,
            Order = #accessories + 1,
            Puffiness = 0.5,
        })
        desc:SetAccessories(accessories, true)
        pcall(function() hum:ApplyDescription(desc) end)
    end)
    return ok
end

--------------------------------------------------------------------------------
-- MAIN APPLY ROUTER
--------------------------------------------------------------------------------
local function ApplyCatalogItem(rawInput, silent)
    local assetId = ParseId(rawInput)
    if not assetId then
        return false, "Invalid ID or URL"
    end

    if FindSaved(assetId) then
        return false, "Already applied (" .. assetId .. ")"
    end

    local info = GetAssetInfo(assetId)
    local assetName   = (info and info.Name) or tostring(assetId)
    local assetTypeId = (info and info.AssetTypeId) or 0
    local assetType   = ASSET_TYPE_MAP[assetTypeId] or "Unknown"

    Log("Applying " .. assetName .. " (" .. assetId .. ") type=" .. assetType)

    local ok, err = false, nil

    if assetType == "Shirt" or assetType == "Pants" or assetType == "TShirt" then
        ok, err = ApplyClothing(assetId, assetType, assetName)
    elseif assetType == "Face" then
        ok, err = ApplyFace(assetId, assetName)
    elseif assetType == "Head" or assetType == "Torso"
        or assetType == "RightArm" or assetType == "LeftArm"
        or assetType == "LeftLeg" or assetType == "RightLeg" then
        ok = ApplyBodyPartDescription(assetId, assetType)
        if not ok then err = "Body part description failed" end
    else
        local model = LoadAssetModel(assetId)
        if model then
            ok = AddAccessorySafe(model, assetId)
            if not ok then err = "Could not attach accessory" end
        end
        if not ok then
            ok = ApplyAccessoryViaDescription(assetId)
            if ok then err = nil; Log("Applied via HumanoidDescription accessory list")
            else err = "LoadAsset failed and Description fallback failed" end
        end
    end

    if ok then
        AddSaved(assetId, assetName, assetType)
        return true, assetName .. " [" .. assetType .. "]"
    else
        return false, err or "Apply failed"
    end
end

--------------------------------------------------------------------------------
-- REMOVE
--------------------------------------------------------------------------------
local function RemoveItem(assetId)
    DestroyTracked(assetId)
    RemoveSaved(assetId)

    local hum = GetHumanoid()
    if hum then
        pcall(function()
            local desc = hum:GetAppliedDescription()
            local accs = desc:GetAccessories(true)
            local newAccs = {}
            for _, a in ipairs(accs) do
                if a.AssetId ~= assetId then table.insert(newAccs, a) end
            end
            desc:SetAccessories(newAccs, true)
            pcall(function() hum:ApplyDescription(desc) end)
        end)
    end
end

local function RemoveAllItems()
    for idStr, list in pairs(State.Instances) do
        for _, inst in ipairs(list) do pcall(function() inst:Destroy() end) end
    end
    State.Instances = {}

    local char = GetChar()
    if char then
        for _, c in ipairs(char:GetChildren()) do
            if c.Name:match("^X0_") then pcall(function() c:Destroy() end) end
        end
    end

    local ids = {}
    for _, entry in ipairs(State.SavedIds) do table.insert(ids, entry.id) end
    State.SavedIds = {}

    local hum = GetHumanoid()
    if hum then
        pcall(function()
            local desc = hum:GetAppliedDescription()
            local accs = desc:GetAccessories(true)
            local newAccs = {}
            for _, a in ipairs(accs) do
                local keep = true
                for _, rid in ipairs(ids) do
                    if a.AssetId == rid then keep = false break end
                end
                if keep then table.insert(newAccs, a) end
            end
            desc:SetAccessories(newAccs, true)
            pcall(function() hum:ApplyDescription(desc) end)
        end)
    end
end

--------------------------------------------------------------------------------
-- FORCE RE-APPLY
--------------------------------------------------------------------------------
local function ForceReapplyAll()
    local char = GetChar()
    local hum  = GetHumanoid()
    if not char or not hum then
        Notif("Re-apply", "No character", 2)
        return
    end

    local snapshot = {}
    for _, entry in ipairs(State.SavedIds) do
        table.insert(snapshot, { id = entry.id, name = entry.name, type = entry.type })
    end

    for idStr, list in pairs(State.Instances) do
        for _, inst in ipairs(list) do pcall(function() inst:Destroy() end) end
    end
    State.Instances = {}
    State.SavedIds = {}

    local okCount, failCount = 0, 0
    for _, item in ipairs(snapshot) do
        local ok = ApplyCatalogItem(tostring(item.id), true)
        if ok then okCount = okCount + 1 else failCount = failCount + 1 end
        task.wait(0.15)
    end

    ReapplyKorblox()
    if State.Headless then SetHeadless(true) end

    Notif("Re-apply", okCount .. " items | Korblox refreshed", 4)
end

--------------------------------------------------------------------------------
-- HEADLESS
--------------------------------------------------------------------------------
local _headBackup = nil
local _faceBackup = {}

function SetHeadless(enable)
    local char = GetChar()
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    if enable then
        if _headBackup == nil then _headBackup = head.Transparency end
        head.Transparency = 1
        for _, d in ipairs(head:GetChildren()) do
            if d:IsA("Decal") then
                if _faceBackup[d] == nil then _faceBackup[d] = d.Transparency end
                d.Transparency = 1
            end
        end
    else
        if _headBackup ~= nil then head.Transparency = _headBackup end
        for d, t in pairs(_faceBackup) do
            if d and d.Parent then d.Transparency = t end
        end
        _faceBackup = {}
        _headBackup = nil
    end
end

--------------------------------------------------------------------------------
-- FLOATING LOGO
--------------------------------------------------------------------------------
local FloatingLogo = {}

local function DestroyLogo()
    if State.LogoGui then pcall(function() State.LogoGui:Destroy() end) end
    local gp = GuiParent()
    if gp then
        for _, c in ipairs(gp:GetChildren()) do
            if c.Name == "X0_Avatar_Logo" then pcall(function() c:Destroy() end) end
        end
    end
    State.LogoGui = nil
    State.LogoImage = nil
end

function FloatingLogo.Build()
    DestroyLogo()
    local gp = GuiParent()
    if not gp then return false end

    local sg = Instance.new("ScreenGui")
    sg.Name = "X0_Avatar_Logo"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 999999
    sg.Enabled = true
    local ok = pcall(function() sg.Parent = gp end)
    if not ok then
        pcall(function() sg.Parent = LocalPlayer:WaitForChild("PlayerGui", 5) end)
    end

    local size = State.LogoSize
    local img = Instance.new("ImageButton")
    img.Name = "Logo"
    img.Size = UDim2.new(0, size, 0, size)
    img.Position = UDim2.new(0, 20, 0, 100)
    img.BackgroundTransparency = 1
    img.BorderSizePixel = 0
    img.Image = TOOL.LogoId
    img.ImageTransparency = State.LogoTransparency
    img.ScaleType = Enum.ScaleType.Fit
    img.AutoButtonColor = false
    img.Active = true
    img.Selectable = true
    img.Visible = true
    img.ZIndex = 100
    img.Parent = sg

    local dragging, dragStart, startPos, dragMoved = false, Vector2.zero, UDim2.new(), false

    img.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = i.Position; startPos = img.Position; dragMoved = false
        end
    end)

    img.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
                      or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            if d.Magnitude > 4 then dragMoved = true end
            img.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                     startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    img.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    img.MouseButton1Click:Connect(function()
        if dragMoved then return end
        pcall(function()
            local h = _G[TOOL_KEY]
            if h and h.window and h.window.Minimize then h.window:Minimize() end
        end)
    end)

    State.LogoGui = sg
    State.LogoImage = img
    return true
end

function FloatingLogo.SetVisible(v)
    State.FloatingLogo = v
    if v then FloatingLogo.Build() else DestroyLogo() end
end

function FloatingLogo.SetSize(sz)
    State.LogoSize = sz
    if State.LogoImage then State.LogoImage.Size = UDim2.new(0, sz, 0, sz) end
end

function FloatingLogo.SetTransparency(a)
    State.LogoTransparency = a
    if State.LogoImage then State.LogoImage.ImageTransparency = a end
end

task.spawn(function()
    pcall(function() ContentProvider:PreloadAsync({TOOL.LogoId}) end)
end)

--------------------------------------------------------------------------------
-- RESPAWN HANDLER
--------------------------------------------------------------------------------
CM:Add(LocalPlayer.CharacterAdded, function()
    task.spawn(function()
        task.wait(1.0)

        local snapshot = {}
        for _, entry in ipairs(State.SavedIds) do
            table.insert(snapshot, entry.id)
        end
        State.SavedIds = {}
        State.Instances = {}

        for _, id in ipairs(snapshot) do
            ApplyCatalogItem(tostring(id), true)
            task.wait(0.15)
        end

        task.wait(0.2)
        ReapplyKorblox()
        if State.Headless then SetHeadless(true) end
    end)
end)

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------
local function CleanupAll()
    pcall(RestoreOriginalAvatar)

    DestroyLogo()
    CM:Cleanup()
    Log("Unloaded - avatar restored")
end

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------
local Window = Fluent:CreateWindow({
    Title       = TOOL.Name,
    SubTitle    = "Catalog Changer v" .. TOOL.Version,
    TabWidth    = 130,
    Size        = UDim2.fromOffset(600, 500),
    Acrylic     = true,
    Theme       = "Dark",
    MinimizeKey = Enum.KeyCode.F8,
})

_G[TOOL_KEY] = { version = TOOL.Version, window = Window, destroy = CleanupAll }

local Tabs = {
    Main      = Window:AddTab({ Title = "Main",     Icon = "box" }),
    Changelog = Window:AddTab({ Title = "Log",      Icon = "file-text" }),
    Settings  = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}

--------------------------------------------------------------------------------
-- MAIN TAB
--------------------------------------------------------------------------------
do
    local T = Tabs.Main
    local inputValue = ""

    T:AddParagraph({
        Title   = "Catalog Item Loader",
        Content = "Paste catalog URL or asset ID.\nExample: https://www.roblox.com/catalog/89728916471078/Black-Plaid-Scarf",
    })

    T:AddInput("CatalogInput", {
        Title       = "Catalog URL / Asset ID",
        Default     = "",
        Placeholder = "URL or ID...",
        Numeric     = false,
        Finished    = false,
    }):OnChanged(function(v)
        inputValue = v
    end)

    T:AddButton({
        Title = "Apply Item",
        Callback = function()
            if inputValue == "" then
                Notif("Error", "Enter a URL or ID first", 3)
                return
            end
            Notif("Loading", "Fetching asset...", 2)
            task.spawn(function()
                local ok, msg = ApplyCatalogItem(inputValue)
                if ok then Notif("Applied", msg, 3)
                else Notif("Failed", tostring(msg), 4) end
            end)
        end,
    })

    T:AddButton({
        Title = "Remove Last Parsed ID",
        Callback = function()
            local id = ParseId(inputValue)
            if not id then Notif("Error", "No valid ID in input", 3) return end
            if FindSaved(id) then
                RemoveItem(id)
                Notif("Removed", "Asset " .. id, 2)
            else
                Notif("Error", "That ID is not applied", 3)
            end
        end,
    })

    T:AddButton({
        Title = "Remove All Applied Items",
        Callback = function()
            RemoveAllItems()
            Notif("Cleared", "All catalog items removed", 2)
        end,
    })

    T:AddButton({
        Title = "List Applied Items",
        Callback = function()
            local count = #State.SavedIds
            for _, entry in ipairs(State.SavedIds) do
                print("[X0 Avatar] " .. entry.name .. " | " .. entry.type .. " | " .. entry.id)
            end
            Notif("Applied", count .. " item(s)  (see console F9)", 3)
        end,
    })

    -- Headless
    T:AddToggle("HeadlessToggle", {
        Title   = "Headless Head",
        Default = false,
    }):OnChanged(function(v)
        State.Headless = v
        SetHeadless(v)
    end)

    -- Korblox
    T:AddParagraph({
        Title   = "Korblox Legs",
        Content = "R15 only. Loads exact Korblox leg assets (139607718 Right / 139607673 Left). Outfit remains 100% intact.",
    })

    T:AddToggle("KorbloxRightToggle", {
        Title       = "Korblox Right Leg (139607718)",
        Description = "Floating Korblox right leg",
        Default     = false,
    }):OnChanged(function(v)
        local ok = ApplyKorbloxRight(v)
        if v and ok then Notif("Korblox", "Right leg on", 2)
        elseif not v then Notif("Korblox", "Right leg off", 2) end
    end)

    T:AddToggle("KorbloxLeftToggle", {
        Title       = "Korblox Left Leg (139607673)",
        Description = "Monster Korblox left leg",
        Default     = false,
    }):OnChanged(function(v)
        local ok = ApplyKorbloxLeft(v)
        if v and ok then Notif("Korblox", "Left leg on", 2)
        elseif not v then Notif("Korblox", "Left leg off", 2) end
    end)

    T:AddButton({
        Title = "Korblox Both Legs",
        Callback = function()
            ApplyKorbloxRight(true)
            ApplyKorbloxLeft(true)
            Notif("Korblox", "Both legs on", 2)
        end,
    })

    T:AddButton({
        Title = "Remove Korblox Legs",
        Callback = function()
            ApplyKorbloxRight(false)
            ApplyKorbloxLeft(false)
            Notif("Korblox", "Legs restored", 2)
        end,
    })

    T:AddButton({
        Title = "Strip All Character Accessories",
        Callback = function()
            local char = GetChar()
            if not char then return end
            for _, child in ipairs(char:GetChildren()) do
                if child:IsA("Accessory") or child:IsA("Accoutrement") then
                    pcall(function() child:Destroy() end)
                end
            end
            Notif("Stripped", "Character accessories removed", 2)
        end,
    })

    T:AddButton({
        Title       = "Force Re-apply All",
        Description = "Reload saved items + Korblox + Headless",
        Callback    = function()
            task.spawn(ForceReapplyAll)
        end,
    })

    T:AddButton({
        Title       = "Restore Original Avatar",
        Description = "Full reset to default avatar look",
        Callback    = function()
            RestoreOriginalAvatar()
            Notif("Restored", "Original avatar restored", 3)
        end,
    })
end

--------------------------------------------------------------------------------
-- CHANGELOG
--------------------------------------------------------------------------------
do
    local T = Tabs.Changelog

    T:AddParagraph({
        Title   = "v1.9.0",
        Content = [[
- Updated Korblox Leg engine to use exact user-requested asset IDs:
  Right Leg: Asset 139607718
  Left Leg: Asset 139607673
- Preserves full clothing and accessories (NO HumanoidDescription calls for Korblox)
- Direct MeshPart swap with welded clone overlay fallback if executor blocks write
- Restores original leg mesh and transparency cleanly on toggle off / reset
]],
    })

    T:AddParagraph({
        Title   = "v1.8.0",
        Content = "- Fixed accessory attachment locks\n- Improved asset model loading chain",
    })
end

--------------------------------------------------------------------------------
-- SETTINGS
--------------------------------------------------------------------------------
do
    local T = Tabs.Settings

    T:AddParagraph({
        Title   = "Floating Logo",
        Content = "No background frame. Drag to move. Click to toggle hub.",
    })

    T:AddToggle("FloatLogo", {
        Title   = "Show Logo",
        Default = true,
    }):OnChanged(function(v)
        FloatingLogo.SetVisible(v)
    end)

    T:AddSlider("LogoSize", {
        Title = "Logo Size", Default = 60, Min = 30, Max = 140, Rounding = 0,
    }):OnChanged(function(v) FloatingLogo.SetSize(v) end)

    T:AddSlider("LogoAlpha", {
        Title = "Logo Transparency %", Default = 10, Min = 0, Max = 90, Rounding = 0,
    }):OnChanged(function(v) FloatingLogo.SetTransparency(v / 100) end)

    T:AddButton({
        Title = "Rebuild Logo",
        Callback = function()
            State.FloatingLogo = true
            FloatingLogo.Build()
            Notif("Logo", "Rebuilt", 2)
        end,
    })

    T:AddButton({
        Title       = "Unload Script",
        Description = "Restore original avatar and close hub",
        Callback    = function()
            CleanupAll()
            _G[TOOL_KEY] = nil
            pcall(function() Fluent:Destroy() end)
        end,
    })

    if InterfaceManager then
        pcall(function()
            InterfaceManager:SetLibrary(Fluent)
            InterfaceManager:SetFolder("X0DEC04T_Avatar")
            InterfaceManager:BuildInterfaceSection(T)
        end)
    end

    if SaveManager then
        pcall(function()
            SaveManager:SetLibrary(Fluent)
            SaveManager:IgnoreThemeSettings()
            SaveManager:SetIgnoreIndexes({})
            SaveManager:SetFolder("X0DEC04T_Avatar/configs")
            SaveManager:BuildConfigSection(T)
        end)
    end
end

--------------------------------------------------------------------------------
-- LOGO STARTUP
--------------------------------------------------------------------------------
task.spawn(function()
    task.wait(0.5)
    if State.FloatingLogo then
        local ok = FloatingLogo.Build()
        if not ok then
            for _ = 1, 3 do
                task.wait(1)
                if FloatingLogo.Build() then break end
            end
        end
    end
    while task.wait(5) do
        if State.FloatingLogo and not (State.LogoGui and State.LogoGui.Parent) then
            FloatingLogo.Build()
        end
    end
end)

--------------------------------------------------------------------------------
-- START
--------------------------------------------------------------------------------
Window:SelectTab(1)
Notif(TOOL.Name, "v" .. TOOL.Version .. " loaded", 4)
Log("v1.9.0 ready")
