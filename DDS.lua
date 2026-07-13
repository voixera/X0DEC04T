--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v1.0 - Drag Drive Simulator [WindUI]
-- Semi-Auto Turbo (safe from anti-cheat)
-- Tabs: Info | Automation | Utility
--═══════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")
local LocalizationService = game:GetService("LocalizationService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

pcall(function()
    LocalizationService.RobloxLocaleId = "en-us"
    LocalizationService.SystemLocaleId = "en-us"
end)

local INSTANCE_KEY = "__X0DEC04T_DDS_v1"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.15)
end

local _t0 = os.clock()
local function Log(m) print(string.format("[X0DEC04T][+%.2fs] %s", os.clock()-_t0, tostring(m))) end
Log("v1.0 DDS starting")

-- WINDUI
local WindUI = nil
for _, url in ipairs({
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
}) do
    local ok, r = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and type(r) == "table" then WindUI = r; break end
end
if not WindUI then warn("WindUI failed"); return end

pcall(function() if WindUI.SetLanguage then WindUI:SetLanguage("en") end end)

local HUB = {
    Name    = "X0DEC04T Hub",
    Game    = "Drag Drive Simulator",
    Version = "1.0",
    Author  = "voixera",
    LogoId  = "rbxassetid://91626851418651",
    Discord = "discord.gg/x0dec04t",
}

-- ═══════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════
local State = {
    -- Quiz Helper
    QuizHelperEnabled = false,
    QuizHighlightColor = Color3.fromRGB(0, 255, 128),
    ShowTopBanner = true,
    ShowMegaButton = true,
    SoundAlert = true,
    PulseSpeed = 0.5,
    HighlightThickness = 8,

    -- Stats
    JobsSolved = 0,
    SessionMoney = 0,
    LastMoneyRaw = 0,
    SessionStartTime = tick(),

    -- Utility
    WalkSpeedEnabled = false,
    WalkSpeedValue = 25,
    DefaultWalkSpeed = 16,

    -- Auto Run To PC
    AutoRunToPC = false,
    PCPosition = nil,

    -- Anti AFK
    AntiAFK = true,

    -- UI
    Notifications = true,
    UIOpen = true,
    LogoGui = nil,

    -- Connections
    QuizOverlay = nil,
    MegaButtonGui = nil,
    Highlights = {},
    QuizLoopRunning = false,
}

local function GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end

local function Notify(t, c, d)
    if not State.Notifications then return end
    pcall(function()
        WindUI:Notify({Title=tostring(t or ""),Content=tostring(c or ""),Duration=tonumber(d) or 3,Icon="bell"})
    end)
end

local function Char() return LocalPlayer.Character end
local function HRP() local c=Char(); return c and c:FindFirstChild("HumanoidRootPart") end
local function Hum() local c=Char(); return c and c:FindFirstChildOfClass("Humanoid") end
local function GetPG() return LocalPlayer:FindFirstChild("PlayerGui") end

-- ═══════════════════════════════════════════
-- ANTI AFK
-- ═══════════════════════════════════════════
LocalPlayer.Idled:Connect(function()
    if State.AntiAFK then
        pcall(function()
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.zero)
        end)
    end
end)

-- ═══════════════════════════════════════════
-- MONEY DETECTION (passive read)
-- ═══════════════════════════════════════════
local function ParseMoney(str)
    if not str then return 0 end
    -- "Rp. 165 129 757" or "Rp. 500.000"
    local clean = str:gsub("Rp%.?", ""):gsub("[^%d]", "")
    return tonumber(clean) or 0
end

local function FindMoneyLabel()
    local pg = GetPG()
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text:find("Rp") then
            -- Skip job salary, quiz answers etc - money is usually big number
            local val = ParseMoney(d.Text)
            if val > 1000 then
                return d
            end
        end
    end
    return nil
end

-- ═══════════════════════════════════════════
-- SOUND ALERTS
-- ═══════════════════════════════════════════
local function PlayBeep()
    if not State.SoundAlert then return end
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://5852063"  -- short beep
        s.Volume = 0.3
        s.Parent = SoundService
        s:Play()
        task.delay(1, function() s:Destroy() end)
    end)
end

-- ═══════════════════════════════════════════
-- QUIZ SOLVER
-- ═══════════════════════════════════════════
local function solveMath(str)
    if not str then return nil end
    local clean = str:gsub("=%s*%?", ""):gsub("%s+", "")
    clean = clean:gsub("[xX×]", "*"):gsub("÷", "/")
    local fn = loadstring("return " .. clean)
    if not fn then return nil end
    local ok, r = pcall(fn)
    return ok and tonumber(r) or nil
end

local function clearHighlights()
    for _, h in ipairs(State.Highlights) do
        pcall(function() h:Destroy() end)
    end
    State.Highlights = {}
end

-- ═══════════════════════════════════════════
-- OVERLAY UI (top banner)
-- ═══════════════════════════════════════════
local function createTopBanner()
    if State.QuizOverlay then pcall(function() State.QuizOverlay:Destroy() end) end
    local sg = Instance.new("ScreenGui")
    sg.Name = "X0_QuizHelper"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 999
    sg.Parent = GuiParent()

    local frame = Instance.new("Frame", sg)
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 500, 0, 80)
    frame.Position = UDim2.new(0.5, -250, 0, 15)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Visible = State.ShowTopBanner

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = State.QuizHighlightColor
    stroke.Thickness = 2
    stroke.Transparency = 0.2

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, 0, 0, 22)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "🎯 X0DEC04T • Quiz Helper"
    title.TextColor3 = State.QuizHighlightColor
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14

    local answerLabel = Instance.new("TextLabel", frame)
    answerLabel.Name = "AnswerLabel"
    answerLabel.Size = UDim2.new(1, -20, 0, 45)
    answerLabel.Position = UDim2.new(0, 10, 0, 30)
    answerLabel.BackgroundTransparency = 1
    answerLabel.Text = "Waiting for quiz..."
    answerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    answerLabel.Font = Enum.Font.GothamBold
    answerLabel.TextSize = 24

    State.QuizOverlay = sg
    return sg
end

-- ═══════════════════════════════════════════
-- MEGA ANSWER BUTTON (huge floating)
-- ═══════════════════════════════════════════
local function createMegaButton()
    if State.MegaButtonGui then pcall(function() State.MegaButtonGui:Destroy() end) end
    if not State.ShowMegaButton then return nil end

    local sg = Instance.new("ScreenGui")
    sg.Name = "X0_MegaButton"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 998
    sg.Parent = GuiParent()

    local frame = Instance.new("Frame", sg)
    frame.Name = "MegaFrame"
    frame.Size = UDim2.new(0, 200, 0, 200)
    frame.Position = UDim2.new(1, -230, 0.5, -100)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Visible = false

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 20)
    local mstroke = Instance.new("UIStroke", frame)
    mstroke.Color = State.QuizHighlightColor
    mstroke.Thickness = 3

    local lbl = Instance.new("TextLabel", frame)
    lbl.Name = "AnswerBig"
    lbl.Size = UDim2.new(1, -10, 0.7, 0)
    lbl.Position = UDim2.new(0, 5, 0.05, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "?"
    lbl.TextColor3 = State.QuizHighlightColor
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextSize = 80
    lbl.TextScaled = true

    local sub = Instance.new("TextLabel", frame)
    sub.Size = UDim2.new(1, 0, 0.25, 0)
    sub.Position = UDim2.new(0, 0, 0.72, 0)
    sub.BackgroundTransparency = 1
    sub.Text = "click this answer"
    sub.TextColor3 = Color3.fromRGB(200, 200, 200)
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 13

    -- Make draggable
    local dragging, dragStart, startPos
    frame.Active = true
    frame.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = inp.Position; startPos = frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+delta.X, startPos.Y.Scale, startPos.Y.Offset+delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    State.MegaButtonGui = sg
    return sg
end

-- ═══════════════════════════════════════════
-- MAIN QUIZ LOOP
-- ═══════════════════════════════════════════
local function StartQuizHelper()
    if State.QuizLoopRunning then return end
    if not State.QuizHelperEnabled then return end

    State.QuizLoopRunning = true
    createTopBanner()
    createMegaButton()

    task.spawn(function()
        local lastQuestion = ""
        while State.QuizHelperEnabled do
            task.wait(0.15)
            local pg = GetPG()
            if not pg then continue end

            local wg = pg:FindFirstChild("WorkGui")
            local overlay = State.QuizOverlay
            local answerLabel = overlay and overlay:FindFirstChild("MainFrame") 
                and overlay.MainFrame:FindFirstChild("AnswerLabel")
            local megaFrame = State.MegaButtonGui and State.MegaButtonGui:FindFirstChild("MegaFrame")
            local megaLabel = megaFrame and megaFrame:FindFirstChild("AnswerBig")

            if wg and wg.Enabled then
                local qLabel = wg:FindFirstChild("QuestionLabel")
                local frame = wg:FindFirstChild("Frame")

                if qLabel and frame and qLabel.Text ~= "" then
                    if qLabel.Text ~= lastQuestion then
                        lastQuestion = qLabel.Text
                        clearHighlights()

                        local answer = solveMath(qLabel.Text)
                        if answer then
                            -- Update banners
                            if answerLabel then
                                answerLabel.Text = qLabel.Text .. "  =  " .. answer
                                answerLabel.TextColor3 = State.QuizHighlightColor
                            end
                            if megaLabel then
                                megaLabel.Text = tostring(answer)
                                megaLabel.TextColor3 = State.QuizHighlightColor
                                megaFrame.Visible = true
                            end

                            PlayBeep()

                            -- Highlight the correct button
                            for _, btn in ipairs(frame:GetChildren()) do
                                if btn:IsA("TextButton") and btn.Name == "AnswerButton" then
                                    local val = tonumber(btn.Text)
                                    if val == answer then
                                        local hStroke = Instance.new("UIStroke")
                                        hStroke.Thickness = State.HighlightThickness
                                        hStroke.Color = State.QuizHighlightColor
                                        hStroke.Transparency = 0
                                        hStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                                        hStroke.Parent = btn
                                        table.insert(State.Highlights, hStroke)

                                        -- Pulse
                                        task.spawn(function()
                                            while hStroke.Parent do
                                                pcall(function()
                                                    TweenService:Create(hStroke, TweenInfo.new(State.PulseSpeed), {Transparency = 0.6}):Play()
                                                end)
                                                task.wait(State.PulseSpeed)
                                                pcall(function()
                                                    TweenService:Create(hStroke, TweenInfo.new(State.PulseSpeed), {Transparency = 0}):Play()
                                                end)
                                                task.wait(State.PulseSpeed)
                                            end
                                        end)

                                        State.JobsSolved = State.JobsSolved + 1
                                    end
                                end
                            end
                        else
                            if answerLabel then
                                answerLabel.Text = "❌ Cannot solve: " .. qLabel.Text
                                answerLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                            end
                        end
                    end
                end
            else
                if lastQuestion ~= "" then
                    lastQuestion = ""
                    clearHighlights()
                    if answerLabel then
                        answerLabel.Text = "Waiting for quiz..."
                        answerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                    end
                    if megaFrame then megaFrame.Visible = false end
                end
            end
        end
        State.QuizLoopRunning = false
    end)
end

local function StopQuizHelper()
    State.QuizHelperEnabled = false
    clearHighlights()
    if State.QuizOverlay then pcall(function() State.QuizOverlay:Destroy() end); State.QuizOverlay = nil end
    if State.MegaButtonGui then pcall(function() State.MegaButtonGui:Destroy() end); State.MegaButtonGui = nil end
end

-- ═══════════════════════════════════════════
-- MONEY TRACKER
-- ═══════════════════════════════════════════
task.spawn(function()
    task.wait(3)
    local lbl = FindMoneyLabel()
    while true do
        task.wait(1.5)
        if not lbl or not lbl.Parent then
            lbl = FindMoneyLabel()
        end
        if lbl then
            local cur = ParseMoney(lbl.Text)
            if State.LastMoneyRaw == 0 then
                State.LastMoneyRaw = cur
            elseif cur > State.LastMoneyRaw then
                local diff = cur - State.LastMoneyRaw
                State.SessionMoney = State.SessionMoney + diff
                State.LastMoneyRaw = cur
            elseif cur < State.LastMoneyRaw then
                -- Player spent money, just update baseline
                State.LastMoneyRaw = cur
            end
        end
    end
end)

-- ═══════════════════════════════════════════
-- UTILITY: WALKSPEED
-- ═══════════════════════════════════════════
local function ApplyWalkSpeed()
    local h = Hum()
    if h then
        pcall(function()
            h.WalkSpeed = State.WalkSpeedEnabled and State.WalkSpeedValue or State.DefaultWalkSpeed
        end)
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    if State.WalkSpeedEnabled then ApplyWalkSpeed() end
end)

-- ═══════════════════════════════════════════
-- WINDUI SETUP
-- ═══════════════════════════════════════════
local Window = WindUI:CreateWindow({
    Title = HUB.Name,
    Icon = "car",
    Author = HUB.Author .. " | " .. HUB.Game,
    Folder = "X0DEC04T_DDS",
    Size = UDim2.fromOffset(560, 400),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 150,
    HideSearchBar = false,
    ScrollBarEnabled = true,
    KeySystem = false,
    Language = "en",
})

Window:EditOpenButton({
    Title = HUB.Name, Icon = "car",
    Enabled = false, Draggable = true,
})

-- ═══════════════════════════════════════════
-- FLOATING LOGO
-- ═══════════════════════════════════════════
local function CreateFloatingLogo()
    if State.LogoGui then pcall(function() State.LogoGui:Destroy() end) end
    local sg = Instance.new("ScreenGui")
    sg.Name = "X0_Logo"; sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true; sg.DisplayOrder = 1000
    sg.Parent = GuiParent()
    local container = Instance.new("Frame")
    container.Size = UDim2.new(0, 60, 0, 60)
    container.Position = UDim2.new(0, 20, 0, 100)
    container.BackgroundTransparency = 1; container.Active = true; container.Parent = sg
    local img = Instance.new("ImageLabel", container)
    img.Size = UDim2.new(1, 0, 1, 0); img.BackgroundTransparency = 1
    img.Image = HUB.LogoId; img.ScaleType = Enum.ScaleType.Fit; img.ZIndex = 2
    local btn = Instance.new("TextButton", container)
    btn.Size = UDim2.new(1, 0, 1, 0); btn.BackgroundTransparency = 1
    btn.Text = ""; btn.AutoButtonColor = false; btn.ZIndex = 3
    btn.MouseEnter:Connect(function()
        TweenService:Create(container, TweenInfo.new(0.15), {Size = UDim2.new(0, 70, 0, 70)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(container, TweenInfo.new(0.15), {Size = UDim2.new(0, 60, 0, 60)}):Play()
    end)
    local dragging, dragStart, startPos, moved = false, nil, nil, false
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = container.Position; moved = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 5 then moved = true end
            container.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+delta.X, startPos.Y.Scale, startPos.Y.Offset+delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragging and not moved then
                pcall(function()
                    if State.UIOpen then Window:Close(); State.UIOpen = false
                    else Window:Open(); State.UIOpen = true end
                end)
            end
            dragging = false
        end
    end)
    State.LogoGui = sg
end
CreateFloatingLogo()

-- ═══════════════════════════════════════════
-- TABS
-- ═══════════════════════════════════════════
local Tabs = {
    Info       = Window:Tab({ Title = "Info",       Icon = "info" }),
    Automation = Window:Tab({ Title = "Automation", Icon = "zap" }),
    Utility    = Window:Tab({ Title = "Utility",    Icon = "wrench" }),
}

-- ═══════════════════════════════════════════
-- INFO TAB
-- ═══════════════════════════════════════════
Tabs.Info:Section({ Title = "About" })
Tabs.Info:Paragraph({
    Title = HUB.Name .. " v" .. HUB.Version,
    Desc = "Game: " .. HUB.Game
        .. "\nDeveloper: " .. HUB.Author
        .. "\nMode: Semi-Auto (Anti-Cheat Safe)"
})

Tabs.Info:Section({ Title = "Live Stats" })
local statsPara = Tabs.Info:Paragraph({
    Title = "Session Stats",
    Desc = "Loading..."
})

task.spawn(function()
    while true do
        task.wait(1.5)
        pcall(function()
            local elapsed = math.floor(tick() - State.SessionStartTime)
            local mins = math.floor(elapsed / 60)
            local secs = elapsed % 60
            local rate = (State.JobsSolved > 0 and elapsed > 0) 
                and math.floor((State.JobsSolved / elapsed) * 3600) or 0
            local moneyRate = (State.SessionMoney > 0 and elapsed > 0)
                and math.floor((State.SessionMoney / elapsed) * 3600) or 0
            local moneyLbl = FindMoneyLabel()
            local curMoney = moneyLbl and moneyLbl.Text or "?"

            local text = "💰 Total Money: " .. curMoney
                .. "\n💵 Earned Session: Rp. " .. State.SessionMoney
                .. "\n🎯 Quizzes Solved: " .. State.JobsSolved
                .. "\n📊 Rate: " .. rate .. " quiz/hr | Rp. " .. moneyRate .. "/hr"
                .. "\n⏱️ Session: " .. string.format("%02d:%02d", mins, secs)
                .. "\n🌐 Ping: " .. math.floor(LocalPlayer:GetNetworkPing() * 1000) .. "ms"
            if statsPara and statsPara.SetDesc then
                pcall(function() statsPara:SetDesc(text) end)
            end
        end)
    end
end)

Tabs.Info:Section({ Title = "How To Use" })
Tabs.Info:Paragraph({
    Title = "Quick Guide",
    Desc = "1. Go to Automation tab\n"
        .. "2. Turn ON 'Quiz Helper'\n"
        .. "3. Interact with PC in office\n"
        .. "4. Correct answer appears:\n"
        .. "   • Big number on right side\n"
        .. "   • Green border on button\n"
        .. "   • Text at top banner\n"
        .. "5. Click green button = money!"
})

Tabs.Info:Paragraph({
    Title = "Why Not Full Auto?",
    Desc = "Drag Drive Simulator has strong anti-cheat.\n"
        .. "Programmatic clicks get you kicked.\n"
        .. "This hub gives you 'instant answer' mode\n"
        .. "= tap once per question, safe & fast."
})

Tabs.Info:Section({ Title = "Community" })
Tabs.Info:Button({
    Title = "Copy Discord",
    Callback = function()
        if setclipboard then setclipboard(HUB.Discord) end
        Notify("Discord", "Copied: " .. HUB.Discord, 3)
    end
})

-- ═══════════════════════════════════════════
-- AUTOMATION TAB
-- ═══════════════════════════════════════════
Tabs.Automation:Section({ Title = "🎯 Job Officer Helper" })

Tabs.Automation:Paragraph({
    Title = "Semi-Auto Turbo",
    Desc = "Instantly detects correct answer.\nYou just tap the highlighted button."
})

Tabs.Automation:Toggle({
    Title = "Quiz Helper",
    Desc = "Auto-detect + highlight correct answer",
    Default = false,
    Callback = function(v)
        State.QuizHelperEnabled = v
        if v then StartQuizHelper() else StopQuizHelper() end
        Notify("Quiz Helper", v and "ENABLED" or "DISABLED", 2)
    end
})

Tabs.Automation:Section({ Title = "Display Options" })

Tabs.Automation:Toggle({
    Title = "Show Top Banner",
    Default = true,
    Callback = function(v)
        State.ShowTopBanner = v
        if State.QuizOverlay then
            local f = State.QuizOverlay:FindFirstChild("MainFrame")
            if f then f.Visible = v end
        end
    end
})

Tabs.Automation:Toggle({
    Title = "Show Mega Answer (Big)",
    Desc = "Giant answer number on side",
    Default = true,
    Callback = function(v)
        State.ShowMegaButton = v
        if v and State.QuizHelperEnabled then createMegaButton() end
        if not v and State.MegaButtonGui then
            pcall(function() State.MegaButtonGui:Destroy() end)
            State.MegaButtonGui = nil
        end
    end
})

Tabs.Automation:Toggle({
    Title = "Sound Alert",
    Desc = "Beep when new question appears",
    Default = true,
    Callback = function(v) State.SoundAlert = v end
})

Tabs.Automation:Section({ Title = "Style" })

Tabs.Automation:Dropdown({
    Title = "Highlight Color",
    Values = { "Green", "Red", "Yellow", "Blue", "Purple", "Cyan", "White", "Orange" },
    Value = "Green",
    Callback = function(v)
        local colors = {
            Green = Color3.fromRGB(0, 255, 128),
            Red = Color3.fromRGB(255, 40, 40),
            Yellow = Color3.fromRGB(255, 220, 60),
            Blue = Color3.fromRGB(60, 120, 255),
            Purple = Color3.fromRGB(180, 60, 220),
            Cyan = Color3.fromRGB(60, 220, 220),
            White = Color3.fromRGB(255, 255, 255),
            Orange = Color3.fromRGB(255, 140, 20),
        }
        State.QuizHighlightColor = colors[v] or colors.Green
    end
})

Tabs.Automation:Slider({
    Title = "Highlight Thickness",
    Value = { Min = 3, Max = 15, Default = 8 },
    Callback = function(v) State.HighlightThickness = tonumber(v) or 8 end
})

Tabs.Automation:Slider({
    Title = "Pulse Speed (x0.1s)",
    Value = { Min = 2, Max = 15, Default = 5 },
    Callback = function(v) State.PulseSpeed = (tonumber(v) or 5) * 0.1 end
})

Tabs.Automation:Section({ Title = "Statistics" })
Tabs.Automation:Button({
    Title = "Reset Counter",
    Callback = function()
        State.JobsSolved = 0
        State.SessionMoney = 0
        State.SessionStartTime = tick()
        local lbl = FindMoneyLabel()
        State.LastMoneyRaw = lbl and ParseMoney(lbl.Text) or 0
        Notify("Stats", "Reset complete", 2)
    end
})

-- ═══════════════════════════════════════════
-- UTILITY TAB
-- ═══════════════════════════════════════════
Tabs.Utility:Section({ Title = "🏃 Movement" })

Tabs.Utility:Slider({
    Title = "Walk Speed",
    Value = { Min = 16, Max = 50, Default = 25 },
    Callback = function(v)
        State.WalkSpeedValue = tonumber(v) or 25
        if State.WalkSpeedEnabled then ApplyWalkSpeed() end
    end
})

Tabs.Utility:Toggle({
    Title = "Enable Walk Speed",
    Default = false,
    Callback = function(v)
        State.WalkSpeedEnabled = v
        ApplyWalkSpeed()
    end
})

Tabs.Utility:Section({ Title = "🛡️ Anti AFK" })
Tabs.Utility:Toggle({
    Title = "Anti AFK",
    Desc = "Prevents 20-min idle kick",
    Default = true,
    Callback = function(v) State.AntiAFK = v end
})

Tabs.Utility:Section({ Title = "🖼️ UI" })
Tabs.Utility:Toggle({
    Title = "Notifications",
    Default = true,
    Callback = function(v) State.Notifications = v end
})
Tabs.Utility:Toggle({
    Title = "Show Floating Logo",
    Default = true,
    Callback = function(v)
        if v then
            if not State.LogoGui or not State.LogoGui.Parent then CreateFloatingLogo()
            else State.LogoGui.Enabled = true end
        else
            if State.LogoGui then State.LogoGui.Enabled = false end
        end
    end
})

Tabs.Utility:Section({ Title = "⚠️ Danger Zone" })
Tabs.Utility:Button({
    Title = "🔴 Unload Hub",
    Callback = function()
        StopQuizHelper()
        if State.LogoGui then pcall(function() State.LogoGui:Destroy() end) end
        local h = Hum(); if h then pcall(function() h.WalkSpeed = State.DefaultWalkSpeed end) end
        _G[INSTANCE_KEY] = nil
        pcall(function() Window:Destroy() end)
    end
})

-- ═══════════════════════════════════════════
-- FINISH
-- ═══════════════════════════════════════════
_G[INSTANCE_KEY] = {
    version = HUB.Version,
    destroy = function()
        StopQuizHelper()
        if State.LogoGui then pcall(function() State.LogoGui:Destroy() end) end
        pcall(function() Window:Destroy() end)
    end,
}

-- Init money baseline
task.spawn(function()
    task.wait(3)
    local lbl = FindMoneyLabel()
    if lbl then State.LastMoneyRaw = ParseMoney(lbl.Text) end
end)

Notify(HUB.Name, "v" .. HUB.Version .. " loaded - Enable Quiz Helper in Automation", 5)
Log("v1.0 DDS fully loaded")
