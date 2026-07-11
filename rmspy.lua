--═══════════════════════════════════════════════════════════════
-- X0DEC04T Remote Spy v1.0.0
-- Logs every RemoteEvent/RemoteFunction call in real-time
-- Use to reverse-engineer admin command signatures
-- SAFE: Uses hookmetamethod (widely supported, low detection)
--═══════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")
local StarterGui        = game:GetService("StarterGui")
local TeleportService   = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer

local INSTANCE_KEY = "__X0DEC04T_SPY_v100_INSTANCE"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.1)
end

local function Log(msg)
    print("[X0-SPY] " .. tostring(msg))
end

Log("Loading Remote Spy v1.0.0")

-- Check executor capabilities
local caps = {
    hookmetamethod = type(hookmetamethod) == "function",
    getrawmetatable = type(getrawmetatable) == "function",
    setreadonly = type(setreadonly) == "function",
    checkcaller = type(checkcaller) == "function",
    getnamecallmethod = type(getnamecallmethod) == "function",
    getcallingscript = type(getcallingscript) == "function",
    hookfunction = type(hookfunction) == "function",
    newcclosure = type(newcclosure) == "function",
    setclipboard = type(setclipboard) == "function",
}
for k, v in pairs(caps) do
    Log("  " .. k .. ": " .. (v and "YES" or "NO"))
end

if not caps.hookmetamethod and not caps.getrawmetatable then
    warn("[X0-SPY] Your executor doesn't support hooking. Spy won't work.")
    return
end

-- Load Rayfield
local Rayfield = nil
for _, url in ipairs({
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source"
}) do
    local ok, r = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and type(r) == "table" then Rayfield = r; break end
end
if not Rayfield then warn("Rayfield failed"); return end

local HUB = {
    Name = "X0DEC04T Remote Spy",
    Version = "1.0.0",
    Author = "voixera",
}

-- CONNECTION MANAGER
local CM = { _list = {} }
function CM:Add(sig, cb)
    if not sig then return end
    local ok, conn = pcall(function() return sig:Connect(cb) end)
    if ok and conn then table.insert(self._list, conn); return conn end
end
function CM:Cleanup()
    for _, c in ipairs(self._list) do pcall(function() c:Disconnect() end) end
    self._list = {}
end

-- ═══════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════
local State = {
    Enabled = true,
    LogToConsole = true,
    LogToGui = true,

    -- Filters
    IgnorePatterns = { "^Chat", "^Default", "SayMessage" },
    FocusPatterns = {},  -- only log if remote name matches (empty = all)
    IgnoreEmpty = false,
    OnlyFromScripts = false,  -- only log calls not from us

    -- Storage
    Logs = {},           -- array of log entries
    MaxLogs = 500,
    UniqueRemotes = {},  -- remoteName -> {count, lastArgs, firstSeen}

    -- Display
    ShowMethod = true,   -- show FireServer/InvokeServer
    ShowScript = true,   -- show calling script name
    ShowArgs = true,     -- show arguments
    ShowTime = true,

    -- Selected for replay
    SelectedRemote = nil,
    SelectedArgs = nil,

    -- Hook state
    Hooked = false,
    OldNamecall = nil,
}

-- ═══════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════

-- Deep serialize a value (table, instance, etc.) to readable string
local function Serialize(val, depth, seen)
    depth = depth or 0
    seen = seen or {}
    if depth > 4 then return "..." end

    local t = typeof(val)
    if t == "string" then
        return string.format("%q", val)
    elseif t == "number" or t == "boolean" or t == "nil" then
        return tostring(val)
    elseif t == "Instance" then
        return string.format("<%s: %s>", val.ClassName, val:GetFullName())
    elseif t == "Vector3" then
        return string.format("Vector3(%.1f,%.1f,%.1f)", val.X, val.Y, val.Z)
    elseif t == "CFrame" then
        return string.format("CFrame(%.1f,%.1f,%.1f)", val.X, val.Y, val.Z)
    elseif t == "Color3" then
        return string.format("Color3(%d,%d,%d)",
            math.floor(val.R*255), math.floor(val.G*255), math.floor(val.B*255))
    elseif t == "UDim2" then
        return "UDim2(...)"
    elseif t == "table" then
        if seen[val] then return "<cycle>" end
        seen[val] = true
        local parts = {}
        local count = 0
        for k, v in pairs(val) do
            count = count + 1
            if count > 10 then table.insert(parts, "..."); break end
            table.insert(parts, tostring(k) .. "=" .. Serialize(v, depth+1, seen))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        return "<" .. t .. ">"
    end
end

local function SerializeArgs(args)
    if #args == 0 then return "()" end
    local parts = {}
    for i, v in ipairs(args) do
        table.insert(parts, Serialize(v))
    end
    return "(" .. table.concat(parts, ", ") .. ")"
end

local function MatchesAnyPattern(str, patterns)
    for _, p in ipairs(patterns) do
        if string.find(str, p) then return true end
    end
    return false
end

-- ═══════════════════════════════════════════
-- GUI — Live Log Window
-- ═══════════════════════════════════════════
local GuiParent = CoreGui
pcall(function() if gethui then GuiParent = gethui() end end)

local SpyGui = Instance.new("ScreenGui")
SpyGui.Name = "X0_RemoteSpyGui"
SpyGui.ResetOnSpawn = false
SpyGui.IgnoreGuiInset = true
SpyGui.DisplayOrder = 9999
SpyGui.Parent = GuiParent

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 700, 0, 400)
Main.Position = UDim2.new(0.5, -350, 1, -420)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = SpyGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)

local st = Instance.new("UIStroke", Main)
st.Color = Color3.fromRGB(100, 150, 255)
st.Thickness = 2

-- Title bar
local TitleBar = Instance.new("Frame", Main)
TitleBar.Size = UDim2.new(1, 0, 0, 28)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
TitleBar.BorderSizePixel = 0
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

local TitleLbl = Instance.new("TextLabel", TitleBar)
TitleLbl.Size = UDim2.new(1, -10, 1, 0)
TitleLbl.Position = UDim2.new(0, 10, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "X0DEC04T Remote Spy v1.0 — Live Log (drag to move)"
TitleLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextSize = 13
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left

local MinBtn = Instance.new("TextButton", TitleBar)
MinBtn.Size = UDim2.new(0, 28, 0, 24)
MinBtn.Position = UDim2.new(1, -60, 0, 2)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 16
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 4)

local CloseBtn = Instance.new("TextButton", TitleBar)
CloseBtn.Size = UDim2.new(0, 28, 0, 24)
CloseBtn.Position = UDim2.new(1, -30, 0, 2)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
CloseBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 4)

-- Log ScrollingFrame
local LogFrame = Instance.new("ScrollingFrame", Main)
LogFrame.Size = UDim2.new(1, -10, 1, -40)
LogFrame.Position = UDim2.new(0, 5, 0, 33)
LogFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
LogFrame.BorderSizePixel = 0
LogFrame.ScrollBarThickness = 6
LogFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
LogFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", LogFrame).CornerRadius = UDim.new(0, 4)

local LogLayout = Instance.new("UIListLayout", LogFrame)
LogLayout.SortOrder = Enum.SortOrder.LayoutOrder
LogLayout.Padding = UDim.new(0, 2)

Instance.new("UIPadding", LogFrame).PaddingLeft = UDim.new(0, 5)

MinBtn.MouseButton1Click:Connect(function()
    if Main.Size.Y.Offset > 30 then
        Main.Size = UDim2.new(0, 700, 0, 28)
    else
        Main.Size = UDim2.new(0, 700, 0, 400)
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    SpyGui.Enabled = false
end)

-- Add log entry to GUI
local function AddLogEntry(remoteType, remoteName, methodName, argsStr, scriptName, timeStr)
    if not State.LogToGui or not SpyGui.Enabled then return end

    local entry = Instance.new("TextButton")
    entry.Size = UDim2.new(1, -10, 0, 20)
    entry.BackgroundColor3 = remoteType == "RemoteEvent"
        and Color3.fromRGB(30, 40, 60)
        or Color3.fromRGB(50, 30, 60)
    entry.BorderSizePixel = 0
    entry.AutoButtonColor = true

    local color = remoteType == "RemoteEvent"
        and Color3.fromRGB(120, 180, 255)
        or Color3.fromRGB(220, 150, 255)

    local prefix = remoteType == "RemoteEvent" and "[E]" or "[F]"
    local text = string.format("%s %s %s:%s%s",
        State.ShowTime and timeStr or "",
        prefix, remoteName, methodName, argsStr)

    if State.ShowScript then
        text = text .. " {" .. scriptName .. "}"
    end

    entry.Text = " " .. text
    entry.TextColor3 = color
    entry.Font = Enum.Font.Code
    entry.TextSize = 11
    entry.TextXAlignment = Enum.TextXAlignment.Left
    entry.TextTruncate = Enum.TextTruncate.AtEnd
    Instance.new("UICorner", entry).CornerRadius = UDim.new(0, 3)
    entry.Parent = LogFrame

    -- Click to copy to clipboard + set as selected
    entry.MouseButton1Click:Connect(function()
        if caps.setclipboard then
            local copyText = string.format("%s:%s%s", remoteName, methodName, argsStr)
            pcall(function() setclipboard(copyText) end)
            Rayfield:Notify({Title="Copied", Content=remoteName, Duration=2})
        end
    end)

    -- Auto-scroll to bottom
    task.wait()
    LogFrame.CanvasPosition = Vector2.new(0, LogFrame.AbsoluteCanvasSize.Y)

    -- Trim old entries
    local children = LogFrame:GetChildren()
    local count = 0
    for _, c in ipairs(children) do
        if c:IsA("TextButton") then count = count + 1 end
    end
    if count > State.MaxLogs then
        for _, c in ipairs(children) do
            if c:IsA("TextButton") then
                c:Destroy()
                count = count - 1
                if count <= State.MaxLogs then break end
            end
        end
    end
end

-- ═══════════════════════════════════════════
-- HOOK — the actual spy
-- ═══════════════════════════════════════════
local function ShouldLog(remoteName)
    if MatchesAnyPattern(remoteName, State.IgnorePatterns) then return false end
    if #State.FocusPatterns > 0 then
        if not MatchesAnyPattern(remoteName, State.FocusPatterns) then return false end
    end
    return true
end

local function OnRemoteCall(remote, methodName, args)
    if not State.Enabled then return end
    if not remote or typeof(remote) ~= "Instance" then return end
    if not (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then return end

    local remoteName = remote.Name
    if not ShouldLog(remoteName) then return end

    if State.IgnoreEmpty and #args == 0 then return end

    local scriptName = "?"
    if caps.getcallingscript then
        local ok, s = pcall(getcallingscript)
        if ok and s then
            scriptName = s:GetFullName()
            if State.OnlyFromScripts and (scriptName:find("X0_") or scriptName:find("Rayfield")) then
                return
            end
        end
    end

    local argsStr = SerializeArgs(args)
    local timeStr = os.date("%H:%M:%S")
    local remoteType = remote:IsA("RemoteEvent") and "RemoteEvent" or "RemoteFunction"

    -- Track unique remotes
    if not State.UniqueRemotes[remoteName] then
        State.UniqueRemotes[remoteName] = {
            count = 0, path = remote:GetFullName(),
            type = remoteType, lastArgs = argsStr,
            firstSeen = timeStr,
        }
    end
    State.UniqueRemotes[remoteName].count = State.UniqueRemotes[remoteName].count + 1
    State.UniqueRemotes[remoteName].lastArgs = argsStr

    -- Save last for replay
    State.SelectedRemote = remote
    State.SelectedArgs = args

    -- Store log
    table.insert(State.Logs, {
        time=timeStr, type=remoteType, name=remoteName, method=methodName,
        args=argsStr, script=scriptName, remote=remote, argsRaw=args,
    })
    if #State.Logs > State.MaxLogs then table.remove(State.Logs, 1) end

    -- Print to console
    if State.LogToConsole then
        Log(string.format("[%s] %s:%s%s {%s}",
            remoteType == "RemoteEvent" and "E" or "F",
            remoteName, methodName, argsStr, scriptName))
    end

    -- Add to GUI
    pcall(AddLogEntry, remoteType, remoteName, methodName, argsStr, scriptName, timeStr)
end

-- Install hook
local function InstallHook()
    if State.Hooked then return end

    if caps.hookmetamethod then
        local success, err = pcall(function()
            State.OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if method == "FireServer" or method == "InvokeServer" then
                    if not checkcaller or not checkcaller() then
                        local args = {...}
                        task.spawn(OnRemoteCall, self, method, args)
                    end
                end
                return State.OldNamecall(self, ...)
            end)
            State.Hooked = true
            Log("Hook installed via hookmetamethod")
        end)
        if not success then
            Log("hookmetamethod failed: " .. tostring(err))
        end
    end

    if not State.Hooked and caps.getrawmetatable and caps.setreadonly then
        local success, err = pcall(function()
            local mt = getrawmetatable(game)
            setreadonly(mt, false)
            State.OldNamecall = mt.__namecall
            mt.__namecall = function(self, ...)
                local method = getnamecallmethod()
                if method == "FireServer" or method == "InvokeServer" then
                    if not checkcaller or not checkcaller() then
                        local args = {...}
                        task.spawn(OnRemoteCall, self, method, args)
                    end
                end
                return State.OldNamecall(self, ...)
            end
            setreadonly(mt, true)
            State.Hooked = true
            Log("Hook installed via getrawmetatable")
        end)
        if not success then
            Log("getrawmetatable failed: " .. tostring(err))
        end
    end

    if not State.Hooked then
        warn("[X0-SPY] Could not install hook. Executor not supported.")
    end
end

-- ═══════════════════════════════════════════
-- REPLAY / MANUAL FIRE
-- ═══════════════════════════════════════════
local function ReplaySelected()
    if not State.SelectedRemote or not State.SelectedArgs then
        Rayfield:Notify({Title="Replay", Content="Nothing selected", Duration=3})
        return
    end
    local remote = State.SelectedRemote
    if not remote or not remote.Parent then
        Rayfield:Notify({Title="Replay", Content="Remote no longer exists", Duration=3})
        return
    end
    local ok, err = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(table.unpack(State.SelectedArgs))
        else
            remote:InvokeServer(table.unpack(State.SelectedArgs))
        end
    end)
    Rayfield:Notify({
        Title="Replay",
        Content = ok and ("Fired " .. remote.Name) or ("Error: " .. tostring(err)),
        Duration = 4
    })
end

-- ═══════════════════════════════════════════
-- EXPORT
-- ═══════════════════════════════════════════
local function ExportLogsText()
    local out = {"=== X0DEC04T REMOTE SPY LOG ==="}
    table.insert(out, "Time: " .. os.date())
    table.insert(out, "Total logs: " .. #State.Logs)
    table.insert(out, "")
    table.insert(out, "=== UNIQUE REMOTES ===")
    for name, data in pairs(State.UniqueRemotes) do
        table.insert(out, string.format("  %s [%s] x%d | %s",
            name, data.type, data.count, data.path))
        table.insert(out, "    last args: " .. tostring(data.lastArgs))
    end
    table.insert(out, "")
    table.insert(out, "=== LAST " .. math.min(#State.Logs, 50) .. " CALLS ===")
    local start = math.max(1, #State.Logs - 49)
    for i = start, #State.Logs do
        local l = State.Logs[i]
        table.insert(out, string.format("[%s] [%s] %s:%s%s {%s}",
            l.time, l.type == "RemoteEvent" and "E" or "F",
            l.name, l.method, l.args, l.script))
    end
    return table.concat(out, "\n")
end

-- ═══════════════════════════════════════════
-- UI (Rayfield control panel)
-- ═══════════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name = HUB.Name .. " v" .. HUB.Version,
    LoadingTitle = HUB.Name,
    LoadingSubtitle = "Remote Interceptor",
    Theme = "DarkBlue",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
})

local Tabs = {}
for _, def in ipairs({
    {key="Main",    name="Main",    icon="radio"},
    {key="Filter",  name="Filters", icon="filter"},
    {key="Uniques", name="Uniques", icon="list"},
    {key="Replay",  name="Replay",  icon="repeat"},
    {key="Export",  name="Export",  icon="save"},
    {key="Settings",name="Settings",icon="settings"},
}) do
    local ok, tab = pcall(function() return Window:CreateTab(def.name, def.icon) end)
    if ok and tab then Tabs[def.key] = tab end
end

-- MAIN
if Tabs.Main then
    local T = Tabs.Main
    T:CreateSection("Info")
    T:CreateLabel(HUB.Name .. " v" .. HUB.Version)
    T:CreateLabel("Hook status: " .. (State.Hooked and "ACTIVE" or "PENDING"))

    T:CreateSection("Master Control")
    T:CreateToggle({Name="Spy Enabled", CurrentValue=true, Flag="EN",
        Callback=function(v) State.Enabled = v end})
    T:CreateToggle({Name="Log to Console (F9)", CurrentValue=true, Flag="LC",
        Callback=function(v) State.LogToConsole = v end})
    T:CreateToggle({Name="Log to GUI Window", CurrentValue=true, Flag="LG",
        Callback=function(v)
            State.LogToGui = v
            SpyGui.Enabled = v
        end})

    T:CreateSection("Quick Actions")
    T:CreateButton({Name="Show GUI Window", Callback=function()
        SpyGui.Enabled = true
    end})
    T:CreateButton({Name="Hide GUI Window", Callback=function()
        SpyGui.Enabled = false
    end})
    T:CreateButton({Name="Clear All Logs", Callback=function()
        State.Logs = {}
        State.UniqueRemotes = {}
        for _, c in ipairs(LogFrame:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        Rayfield:Notify({Title="Cleared", Content="All logs cleared", Duration=2})
    end})

    T:CreateSection("How to Use")
    T:CreateLabel("1. Spy hooks all remote calls automatically")
    T:CreateLabel("2. Watch the GUI window at bottom of screen")
    T:CreateLabel("3. When admin uses command, you'll see it")
    T:CreateLabel("4. Click any log line to copy to clipboard")
    T:CreateLabel("5. Use Replay tab to re-fire captured calls")
end

-- FILTER
if Tabs.Filter then
    local T = Tabs.Filter
    T:CreateSection("Ignore Patterns (regex)")
    T:CreateLabel("Skip logging remotes matching these:")
    T:CreateInput({Name="Add Ignore Pattern",
        PlaceholderText="e.g. Chat or ^Default",
        RemoveTextAfterFocusLost=true,
        Callback=function(v)
            if v and v ~= "" then
                table.insert(State.IgnorePatterns, v)
                Rayfield:Notify({Title="Filter", Content="Added ignore: "..v, Duration=2})
            end
        end})
    T:CreateButton({Name="Clear Ignore List", Callback=function()
        State.IgnorePatterns = {}
        Rayfield:Notify({Title="Filter", Content="Cleared", Duration=2})
    end})
    T:CreateButton({Name="Reset Default Ignores", Callback=function()
        State.IgnorePatterns = { "^Chat", "^Default", "SayMessage" }
    end})

    T:CreateSection("Focus Patterns (only log these)")
    T:CreateLabel("If set, ONLY log remotes matching:")
    T:CreateInput({Name="Add Focus Pattern",
        PlaceholderText="e.g. Admin or Kick",
        RemoveTextAfterFocusLost=true,
        Callback=function(v)
            if v and v ~= "" then
                table.insert(State.FocusPatterns, v)
                Rayfield:Notify({Title="Filter", Content="Added focus: "..v, Duration=2})
            end
        end})
    T:CreateButton({Name="Clear Focus List (log all)", Callback=function()
        State.FocusPatterns = {}
    end})

    T:CreateSection("Quick Focus Presets")
    T:CreateButton({Name="Focus: Admin remotes only", Callback=function()
        State.FocusPatterns = { "Admin", "admin" }
        Rayfield:Notify({Title="Focus", Content="Only admin remotes", Duration=3})
    end})
    T:CreateButton({Name="Focus: Kick/Kill/Ban", Callback=function()
        State.FocusPatterns = { "Kick", "kick", "Kill", "kill", "Ban", "ban", "Respawn" }
    end})
    T:CreateButton({Name="Focus: VIP/Whitelist", Callback=function()
        State.FocusPatterns = { "VIP", "Whitelist", "Role" }
    end})

    T:CreateSection("Other Filters")
    T:CreateToggle({Name="Ignore Empty-Args Calls", CurrentValue=false, Flag="IE",
        Callback=function(v) State.IgnoreEmpty = v end})
    T:CreateToggle({Name="Ignore Calls From My Scripts", CurrentValue=false, Flag="IM",
        Callback=function(v) State.OnlyFromScripts = v end})
end

-- UNIQUES
if Tabs.Uniques then
    local T = Tabs.Uniques
    T:CreateSection("Unique Remotes Called")
    T:CreateLabel("Shows every remote seen at least once")

    T:CreateButton({Name="Print Uniques to Console", Callback=function()
        local out = {"=== UNIQUE REMOTES ==="}
        for name, data in pairs(State.UniqueRemotes) do
            table.insert(out, string.format("%s [%s] x%d",
                name, data.type, data.count))
            table.insert(out, "  path: " .. data.path)
            table.insert(out, "  last: " .. data.lastArgs)
        end
        Log(table.concat(out, "\n"))
        Rayfield:Notify({Title="Uniques", Content="Printed to F9", Duration=3})
    end})

    T:CreateButton({Name="Copy Uniques to Clipboard", Callback=function()
        if caps.setclipboard then
            local out = {"=== UNIQUE REMOTES ==="}
            for name, data in pairs(State.UniqueRemotes) do
                table.insert(out, string.format("%s [%s] x%d | %s",
                    name, data.type, data.count, data.path))
                table.insert(out, "  last: " .. data.lastArgs)
            end
            setclipboard(table.concat(out, "\n"))
            Rayfield:Notify({Title="Copied", Content=table.concat(out, "\n"):sub(1,50), Duration=3})
        end
    end})

    T:CreateButton({Name="Reset Unique Counter", Callback=function()
        State.UniqueRemotes = {}
    end})
end

-- REPLAY
if Tabs.Replay then
    local T = Tabs.Replay
    T:CreateSection("Replay Last Captured Call")
    T:CreateLabel("Re-fires the most recent captured remote")

    T:CreateButton({Name="Replay Last Captured", Callback=ReplaySelected})

    T:CreateSection("Manual Fire by Name")
    local manualName = ""
    local manualArg1 = ""
    local manualArg2 = ""

    T:CreateInput({Name="Remote Name (exact)",
        PlaceholderText="AdminInputEvent",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) manualName = tostring(v or "") end})

    T:CreateInput({Name="Arg 1 (string)",
        PlaceholderText=":kick playername",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) manualArg1 = tostring(v or "") end})

    T:CreateInput({Name="Arg 2 (optional, player name to convert)",
        PlaceholderText="playername",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) manualArg2 = tostring(v or "") end})

    T:CreateButton({Name="Fire Manual (find remote by name)", Callback=function()
        if manualName == "" then
            Rayfield:Notify({Title="Manual", Content="Enter remote name", Duration=3})
            return
        end
        -- Search for remote
        local remote
        for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
            if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) and v.Name == manualName then
                remote = v; break
            end
        end
        if not remote then
            Rayfield:Notify({Title="Manual", Content="Remote not found", Duration=3})
            return
        end

        local args = {}
        if manualArg1 ~= "" then table.insert(args, manualArg1) end
        if manualArg2 ~= "" then
            local plr = Players:FindFirstChild(manualArg2)
            table.insert(args, plr or manualArg2)
        end

        local ok, err = pcall(function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer(table.unpack(args))
            else
                remote:InvokeServer(table.unpack(args))
            end
        end)
        Rayfield:Notify({
            Title="Manual",
            Content = ok and ("Fired " .. remote.Name) or ("Err: " .. tostring(err)),
            Duration = 4
        })
    end})

    T:CreateSection("Replay Options")
    T:CreateLabel("Click a log entry in GUI to copy its call")
    T:CreateLabel("Also see Uniques tab to view all seen remotes")
end

-- EXPORT
if Tabs.Export then
    local T = Tabs.Export
    T:CreateSection("Export Data")

    T:CreateButton({Name="Copy Full Log to Clipboard", Callback=function()
        if caps.setclipboard then
            local text = ExportLogsText()
            setclipboard(text)
            Rayfield:Notify({Title="Export", Content="Copied " .. #State.Logs .. " logs", Duration=3})
        else
            Rayfield:Notify({Title="Export", Content="No setclipboard support", Duration=3})
        end
    end})

    T:CreateButton({Name="Print Full Log to Console", Callback=function()
        print(ExportLogsText())
    end})

    T:CreateButton({Name="Save to _G.X0SpyLog", Callback=function()
        _G.X0SpyLog = ExportLogsText()
        _G.X0SpyLogs = State.Logs
        _G.X0SpyUniques = State.UniqueRemotes
        Rayfield:Notify({Title="Saved", Content="_G.X0SpyLog / X0SpyLogs / X0SpyUniques", Duration=4})
    end})
end

-- SETTINGS
if Tabs.Settings then
    local T = Tabs.Settings
    T:CreateSection("Display Options")
    T:CreateToggle({Name="Show timestamps", CurrentValue=true, Flag="ST",
        Callback=function(v) State.ShowTime = v end})
    T:CreateToggle({Name="Show script name", CurrentValue=true, Flag="SS",
        Callback=function(v) State.ShowScript = v end})
    T:CreateToggle({Name="Show args", CurrentValue=true, Flag="SA",
        Callback=function(v) State.ShowArgs = v end})

    T:CreateSection("Storage")
    T:CreateSlider({Name="Max stored logs", Range={50,2000}, Increment=50, CurrentValue=500, Flag="ML",
        Callback=function(v) State.MaxLogs = tonumber(v) or 500 end})

    T:CreateSection("Executor Capabilities")
    for k, v in pairs(caps) do
        T:CreateLabel(k .. ": " .. (v and "YES" or "NO"))
    end

    T:CreateSection("Danger Zone")
    T:CreateButton({Name="Unload Spy", Callback=function()
        State.Enabled = false
        if SpyGui then pcall(function() SpyGui:Destroy() end) end
        CM:Cleanup()
        _G[INSTANCE_KEY] = nil
        pcall(function() Rayfield:Destroy() end)
    end})
end

-- Toggle GUI hotkey (F8)
CM:Add(UserInputService.InputBegan, function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.F8 then
        SpyGui.Enabled = not SpyGui.Enabled
    end
end)

-- INSTALL HOOK
InstallHook()

_G[INSTANCE_KEY] = {
    version = HUB.Version, timestamp = os.time(),
    logs = State.Logs, uniques = State.UniqueRemotes,
    destroy = function()
        State.Enabled = false
        if SpyGui then pcall(function() SpyGui:Destroy() end) end
        CM:Cleanup()
        pcall(function() Rayfield:Destroy() end)
    end,
}

Rayfield:Notify({
    Title = HUB.Name,
    Content = "v" .. HUB.Version .. " loaded. Press F8 to toggle GUI.",
    Duration = 5,
})
Log("Ready. Watching all remote calls.")
