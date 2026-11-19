--[[
    By cuqy puky
]]

-- ========================
-- SERVICES
-- ========================
local UserInputService    = game:GetService("UserInputService")
local RunService          = game:GetService("RunService")
local Players             = game:GetService("Players")
local CoreGui             = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService        = game:GetService("TweenService")
local Lighting            = game:GetService("Lighting")
local HttpService         = game:GetService("HttpService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ========================
-- STATE / VARIABEL
-- ========================
local lungeEnabled      = false
local espEnabled        = false
local crosshairEnabled  = false
local fovEnabled        = false
local skillcheckEnabled = false
local skillcheckNotPerfectEnabled = false
local menuVisible       = true

local isMouseDown        = false
local isRightMouseDown   = false
local toggleKey          = Enum.KeyCode.P
local hideMenuKey        = Enum.KeyCode.RightControl
local lungeSpeed    = 30
local crosshairType = "Dot"
local targetFOV     = 100
local defaultFOV    = Camera.FieldOfView

-- ========================
-- UTILS
-- ========================
local function isKiller(player)
    return player.Team and (
        player.Team.Name == "Killer"  or
        player.Team.Name == "Slasher" or
        player.Team.Name == "Traitor"
    )
end

local function isMouseOverFrame(frame)
    if not frame.Visible then return false end
    local mouse = UserInputService:GetMouseLocation()
    local pos   = frame.AbsolutePosition
    local size  = frame.AbsoluteSize
    return mouse.X >= pos.X and mouse.X <= pos.X + size.X
       and mouse.Y >= pos.Y and mouse.Y <= pos.Y + size.Y
end

-- ========================
-- GUI SETUP
-- ========================
if CoreGui:FindFirstChild("VD_V10_GUI") then
    CoreGui:FindFirstChild("VD_V10_GUI"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "VD_V10_GUI"
ScreenGui.Parent          = CoreGui
ScreenGui.ResetOnSpawn    = false
ScreenGui.DisplayOrder    = 999
ScreenGui.IgnoreGuiInset  = true

local C = {
    bg        = Color3.fromRGB(10,  12,  18),
    panel     = Color3.fromRGB(16,  18,  26),
    card      = Color3.fromRGB(20,  23,  34),
    border    = Color3.fromRGB(30,  34,  52),
    accent    = Color3.fromRGB(0,   200, 255),
    accentDim = Color3.fromRGB(0,   120, 160),
    red       = Color3.fromRGB(255, 60,  80),
    green     = Color3.fromRGB(0,   220, 140),
    text      = Color3.fromRGB(220, 225, 240),
    subtext   = Color3.fromRGB(120, 130, 160),
    off       = Color3.fromRGB(38,  42,  60),
    white     = Color3.fromRGB(255, 255, 255),
}

local function addStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color      = color or C.border
    s.Thickness  = thickness or 1
    s.Parent     = parent
    return s
end

local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = parent
    return c
end

local function addGradient(parent, c0, c1, rotation)
    local g = Instance.new("UIGradient")
    g.Color    = ColorSequence.new(c0, c1)
    g.Rotation = rotation or 90
    g.Parent   = parent
    return g
end

local MainFrame = Instance.new("Frame")
MainFrame.Name              = "MainFrame"
MainFrame.Parent            = ScreenGui
MainFrame.BackgroundColor3  = C.bg
MainFrame.BorderSizePixel   = 0
MainFrame.Position          = UDim2.new(1, -410, 0, 10)
MainFrame.Size              = UDim2.new(0, 400, 0, 440)
MainFrame.Active            = true
MainFrame.Draggable         = true
addCorner(MainFrame, 12)
addStroke(MainFrame, C.border, 1.5)
addGradient(MainFrame, Color3.fromRGB(12, 14, 22), Color3.fromRGB(8, 10, 16), 135)

local Sidebar = Instance.new("Frame")
Sidebar.Name              = "Sidebar"
Sidebar.Parent            = MainFrame
Sidebar.BackgroundColor3  = C.panel
Sidebar.BorderSizePixel   = 0
Sidebar.Size              = UDim2.new(0, 120, 1, 0)
addStroke(Sidebar, C.border, 1)

local Logo = Instance.new("TextLabel")
Logo.Parent             = Sidebar
Logo.BackgroundTransparency = 1
Logo.Position           = UDim2.new(0, 0, 0, 15)
Logo.Size               = UDim2.new(1, 0, 0, 30)
Logo.Font               = Enum.Font.GothamBlack
Logo.Text               = "HANGMA"
Logo.TextColor3         = C.accent
Logo.TextSize           = 18

local TabContainer = Instance.new("Frame")
TabContainer.Parent             = Sidebar
TabContainer.BackgroundTransparency = 1
TabContainer.Position           = UDim2.new(0, 10, 0, 60)
TabContainer.Size               = UDim2.new(1, -20, 1, -70)
local TabListLayout = Instance.new("UIListLayout")
TabListLayout.Parent = TabContainer
TabListLayout.Padding = UDim.new(0, 6)

local ContentArea = Instance.new("Frame")
ContentArea.Name              = "ContentArea"
ContentArea.Parent            = MainFrame
ContentArea.BackgroundTransparency = 1
ContentArea.Position          = UDim2.new(0, 120, 0, 0)
ContentArea.Size              = UDim2.new(1, -120, 1, 0)

local function createTabFrame(name)
    local f = Instance.new("ScrollingFrame")
    f.Name                = name .. "Frame"
    f.Parent              = ContentArea
    f.BackgroundTransparency = 1
    f.BorderSizePixel     = 0
    f.Size                = UDim2.new(1, 0, 1, 0)
    f.ScrollBarThickness  = 2
    f.ScrollBarImageColor3 = C.accent
    f.Visible             = false
    f.CanvasSize          = UDim2.new(0, 0, 0, 800)
    local pad = Instance.new("UIPadding")
    pad.Parent = f
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.PaddingTop = UDim.new(0, 12)
    return f
end

local HomeFrame     = createTabFrame("Home")
local SurvivorFrame = createTabFrame("Survivor")
local MovementFrame = createTabFrame("Movement")
local VisualFrame   = createTabFrame("Visual")
local LainnyaFrame  = createTabFrame("Lainnya")

local tabs = {
    { name = "HOME",     frame = HomeFrame     },
    { name = "SURVIVOR", frame = SurvivorFrame },
    { name = "MOVEMENT", frame = MovementFrame },
    { name = "VISUAL",   frame = VisualFrame   },
    { name = "LAINNYA",  frame = LainnyaFrame  },
}

local function showTab(name)
    for _, t in pairs(tabs) do t.frame.Visible = (t.name == name) end
end

for _, t in pairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Parent             = TabContainer
    btn.BackgroundColor3   = C.card
    btn.Size               = UDim2.new(1, 0, 0, 32)
    btn.Font               = Enum.Font.GothamBold
    btn.Text               = t.name
    btn.TextColor3         = C.subtext
    btn.TextSize           = 11
    btn.AutoButtonColor    = false
    addCorner(btn, 6)
    addStroke(btn, C.border, 1)
    btn.MouseButton1Click:Connect(function()
        showTab(t.name)
        for _, other in pairs(TabContainer:GetChildren()) do
            if other:IsA("TextButton") then
                other.TextColor3 = C.subtext
                other.BackgroundColor3 = C.card
            end
        end
        btn.TextColor3 = C.white
        btn.BackgroundColor3 = C.accentDim
    end)
end

local function createCard(parent, yOffset, height)
    local card = Instance.new("Frame")
    card.Parent             = parent
    card.BackgroundColor3   = C.card
    card.BorderSizePixel    = 0
    card.Position           = UDim2.new(0, 0, 0, yOffset)
    card.Size               = UDim2.new(1, 0, 0, height)
    addCorner(card, 8)
    addStroke(card, C.border, 1)
    return card
end

local function createToggle(parent, icon, text, yOffset, default, callback)
    local card = createCard(parent, yOffset, 42)
    local iconLbl = Instance.new("TextLabel")
    iconLbl.Parent             = card
    iconLbl.BackgroundTransparency = 1
    iconLbl.Position           = UDim2.new(0, 10, 0, 0)
    iconLbl.Size               = UDim2.new(0, 24, 1, 0)
    iconLbl.Font               = Enum.Font.GothamBold
    iconLbl.Text               = icon
    iconLbl.TextColor3         = C.accentDim
    iconLbl.TextSize           = 14
    local label = Instance.new("TextLabel")
    label.Parent             = card
    label.BackgroundTransparency = 1
    label.Position           = UDim2.new(0, 38, 0, 0)
    label.Size               = UDim2.new(0.5, 0, 1, 0)
    label.Font               = Enum.Font.Gotham
    label.Text               = text
    label.TextColor3         = C.text
    label.TextSize           = 13
    label.TextXAlignment     = Enum.TextXAlignment.Left
    local btn = Instance.new("TextButton")
    btn.Parent             = card
    btn.BackgroundColor3   = default and C.accent or C.off
    btn.Position           = UDim2.new(1, -50, 0.5, -11)
    btn.Size               = UDim2.new(0, 40, 0, 22)
    btn.Text               = ""
    btn.AutoButtonColor    = false
    addCorner(btn, 11)
    local circle = Instance.new("Frame")
    circle.Parent           = btn
    circle.BackgroundColor3 = C.white
    circle.Position         = default and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 4, 0.5, -8)
    circle.Size             = UDim2.new(0, 16, 0, 16)
    addCorner(circle, 8)
    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and C.accent or C.off
        circle:TweenPosition(state and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 4, 0.5, -8), "Out", "Quad", 0.2, true)
        callback(state)
    end)
    return function(v)
        state = v
        btn.BackgroundColor3 = state and C.accent or C.off
        circle.Position = state and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 4, 0.5, -8)
    end
end

local function createKeybindRow(parent, icon, text, currentKey, yOffset, callback)
    local card = createCard(parent, yOffset, 42)
    local iconLbl = Instance.new("TextLabel")
    iconLbl.Parent             = card
    iconLbl.BackgroundTransparency = 1
    iconLbl.Position           = UDim2.new(0, 10, 0, 0)
    iconLbl.Size               = UDim2.new(0, 24, 1, 0)
    iconLbl.Font               = Enum.Font.GothamBold
    iconLbl.Text               = icon
    iconLbl.TextColor3         = C.accentDim
    iconLbl.TextSize           = 14
    local label = Instance.new("TextLabel")
    label.Parent             = card
    label.BackgroundTransparency = 1
    label.Position           = UDim2.new(0, 38, 0, 0)
    label.Size               = UDim2.new(0.45, 0, 1, 0)
    label.Font               = Enum.Font.Gotham
    label.Text               = text
    label.TextColor3         = C.text
    label.TextSize           = 13
    label.TextXAlignment     = Enum.TextXAlignment.Left
    local bindBtn = Instance.new("TextButton")
    bindBtn.Parent             = card
    bindBtn.BackgroundColor3   = C.off
    bindBtn.Position           = UDim2.new(1, -72, 0.5, -13)
    bindBtn.Size               = UDim2.new(0, 64, 0, 26)
    bindBtn.Font               = Enum.Font.GothamBold
    bindBtn.Text               = currentKey.Name
    bindBtn.TextColor3         = C.accent
    bindBtn.TextSize           = 11
    bindBtn.AutoButtonColor    = false
    addCorner(bindBtn, 6)
    addStroke(bindBtn, C.border, 1)
    bindBtn.MouseButton1Click:Connect(function()
        bindBtn.Text = "..."
        local connection
        connection = UserInputService.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Keyboard then
                bindBtn.Text = i.KeyCode.Name
                callback(i.KeyCode)
                connection:Disconnect()
            end
        end)
    end)
end

local function createSlider(parent, icon, text, min, max, defaultVal, yOffset, callback)
    local card = createCard(parent, yOffset, 56)
    local label = Instance.new("TextLabel")
    label.Parent             = card
    label.BackgroundTransparency = 1
    label.Position           = UDim2.new(0, 10, 0, 5)
    label.Size               = UDim2.new(1, -20, 0, 20)
    label.Font               = Enum.Font.Gotham
    label.Text               = icon .. " " .. text .. " (" .. defaultVal .. ")"
    label.TextColor3         = C.text
    label.TextSize           = 12
    label.TextXAlignment     = Enum.TextXAlignment.Left
    local sliderBG = Instance.new("Frame")
    sliderBG.Parent             = card
    sliderBG.BackgroundColor3   = C.off
    sliderBG.Position           = UDim2.new(0, 10, 0, 32)
    sliderBG.Size               = UDim2.new(1, -20, 0, 6)
    addCorner(sliderBG, 3)
    local sliderFill = Instance.new("Frame")
    sliderFill.Parent           = sliderBG
    sliderFill.BackgroundColor3 = C.accent
    sliderFill.Size             = UDim2.new((defaultVal - min) / (max - min), 0, 1, 0)
    addCorner(sliderFill, 3)
    local isDragging = false
    local function update(input)
        local pos = math.clamp((input.Position.X - sliderBG.AbsolutePosition.X) / sliderBG.AbsoluteSize.X, 0, 1)
        sliderFill.Size = UDim2.new(pos, 0, 1, 0)
        local val = math.floor(min + (max - min) * pos)
        label.Text = icon .. " " .. text .. " (" .. val .. ")"
        callback(val)
    end
    sliderBG.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then isDragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then update(input) end
    end)
end

local function createLabelInput(parent, icon, text, defaultVal, yOffset, callback)
    local card = createCard(parent, yOffset, 42)
    local label = Instance.new("TextLabel")
    label.Parent             = card
    label.BackgroundTransparency = 1
    label.Position           = UDim2.new(0, 10, 0, 0)
    label.Size               = UDim2.new(0.6, 0, 1, 0)
    label.Font               = Enum.Font.Gotham
    label.Text               = icon .. " " .. text
    label.TextColor3         = C.text
    label.TextSize           = 13
    label.TextXAlignment     = Enum.TextXAlignment.Left
    local input = Instance.new("TextBox")
    input.Parent             = card
    input.BackgroundColor3   = C.off
    input.Position           = UDim2.new(1, -74, 0.5, -13)
    input.Size               = UDim2.new(0, 64, 0, 26)
    input.Font               = Enum.Font.GothamBold
    input.Text               = defaultVal
    input.TextColor3         = C.white
    input.TextSize           = 11
    addCorner(input, 6)
    addStroke(input, C.border, 1)
    input.FocusLost:Connect(function() callback(input.Text) end)
    return input
end

local function createSection(parent, text, yOffset)
    local lbl = Instance.new("TextLabel")
    lbl.Parent             = parent
    lbl.BackgroundTransparency = 1
    lbl.Position           = UDim2.new(0, 4, 0, yOffset)
    lbl.Size               = UDim2.new(1, -8, 0, 22)
    lbl.Font               = Enum.Font.GothamBold
    lbl.Text               = text
    lbl.TextColor3         = C.accent
    lbl.TextSize           = 11
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    local line = Instance.new("Frame")
    line.Parent             = lbl
    line.BackgroundColor3   = C.accent
    line.Size               = UDim2.new(1, 0, 0, 1)
    line.Position           = UDim2.new(0, 0, 1, -2)
    line.BorderSizePixel    = 0
    line.BackgroundTransparency = 0.6
end

-- ========================
-- HOME TAB
-- ========================
local BannerCard = createCard(HomeFrame, 5, 80)
BannerCard.BackgroundColor3 = C.panel
addGradient(BannerCard, Color3.fromRGB(0, 60, 80), Color3.fromRGB(12, 14, 22), 135)
local BannerTitle = Instance.new("TextLabel")
BannerTitle.Parent             = BannerCard
BannerTitle.BackgroundTransparency = 1
BannerTitle.Position           = UDim2.new(0, 14, 0, 8)
BannerTitle.Size               = UDim2.new(1, -14, 0, 30)
BannerTitle.Font               = Enum.Font.GothamBlack
BannerTitle.Text               = "BY CUQY PUQY"
BannerTitle.TextColor3         = C.accent
BannerTitle.TextSize           = 20
BannerTitle.TextXAlignment     = Enum.TextXAlignment.Left
local BannerSub = Instance.new("TextLabel")
BannerSub.Parent             = BannerCard
BannerSub.BackgroundTransparency = 1
BannerSub.Position           = UDim2.new(0, 14, 0, 36)
BannerSub.Size               = UDim2.new(1, -14, 0, 18)
BannerSub.Font               = Enum.Font.Gotham
BannerSub.Text               = "MENJADI HANGMA"
BannerSub.TextColor3         = C.subtext
BannerSub.TextSize           = 11
BannerSub.TextXAlignment     = Enum.TextXAlignment.Left

createSection(HomeFrame, "KEYBIND DEFAULT", 93)
local keybinds = {
    { key = "R-CTRL", desc = "Sembunyikan / Tampilkan Menu" },
    { key = "P",      desc = "Toggle Infinite Lunge"       },
}
for i, kb in ipairs(keybinds) do
    local kCard = createCard(HomeFrame, 118 + (i-1) * 48, 40)
    local kLabel = Instance.new("TextLabel")
    kLabel.Parent             = kCard
    kLabel.BackgroundTransparency = 1
    kLabel.Position           = UDim2.new(0, 10, 0, 0)
    kLabel.Size               = UDim2.new(0.6, 0, 1, 0)
    kLabel.Font               = Enum.Font.Gotham
    kLabel.Text               = kb.desc
    kLabel.TextColor3         = C.text
    kLabel.TextSize           = 11
    kLabel.TextXAlignment     = Enum.TextXAlignment.Left
    local kBadge = Instance.new("TextLabel")
    kBadge.Parent             = kCard
    kBadge.BackgroundColor3   = C.off
    kBadge.Position           = UDim2.new(1, -74, 0.5, -11)
    kBadge.Size               = UDim2.new(0, 64, 0, 22)
    kBadge.Font               = Enum.Font.GothamBold
    kBadge.Text               = kb.key
    kBadge.TextColor3         = C.accent
    kBadge.TextSize           = 10
    addCorner(kBadge, 4)
    addStroke(kBadge, C.border, 1)
end

-- ========================
-- SURVIVOR TAB
-- ========================
createSection(SurvivorFrame, "SKILLCHECK", 5)
local updateSkillcheckUI = createToggle(SurvivorFrame, "✓", "Skillcheck Sempurna", 30, false, function(v) skillcheckEnabled = v end)
local updateSkillcheckNotPerfectUI = createToggle(SurvivorFrame, "✗", "Auto Gen (Not Perfect)", 78, false, function(v) skillcheckNotPerfectEnabled = v end)

-- ========================
-- MOVEMENT
-- ========================
createSection(MovementFrame, "MOVEMENT", 5)
local updateLungeUI = createToggle(MovementFrame, "↯", "Lunge Tak Terbatas", 30, false, function(v) lungeEnabled = v end)
createKeybindRow(MovementFrame, "⌨", "Set Tombol Lunge:", toggleKey, 78, function(key) toggleKey = key end)
createLabelInput(MovementFrame, "⚡", "Kecepatan Lunge:", "30", 126, function(txt) lungeSpeed = tonumber(txt) or 30 end)

createSection(MovementFrame, "FOV", 178)
local updateFOVUI = createToggle(MovementFrame, "◎", "Pengubah FOV", 203, false, function(v) fovEnabled = v end)
createLabelInput(MovementFrame, "👁", "Target FOV:", "100", 251, function(txt) targetFOV = tonumber(txt) or 100 end)

-- ========================
-- VISUAL TAB
-- ========================
createSection(VisualFrame, "ESP", 5)
local updateESPUI = createToggle(VisualFrame, "👁", "ESP Highlight Aktif", 30, false, function(v) espEnabled = v end)
local updateCrosshairUI = createToggle(VisualFrame, "⌖", "Custom Crosshair", 78, false, function(v) crosshairEnabled = v end)

-- ========================
-- CROSSHAIR GUI
-- ========================
local CrosshairGUI = Instance.new("Frame")
CrosshairGUI.Name            = "CustomCrosshair"
CrosshairGUI.Parent          = ScreenGui
CrosshairGUI.BackgroundColor3  = C.red
CrosshairGUI.BorderSizePixel   = 0
CrosshairGUI.Size              = UDim2.new(0, 6, 0, 6)
CrosshairGUI.Position          = UDim2.new(0.5, -3, 0.5, -3)
CrosshairGUI.Visible           = false
addCorner(CrosshairGUI, 3)

-- ========================
-- ESP LOGIC
-- ========================
local function applyESP(character, player)
    if not character:FindFirstChild("ESPHighlight") then
        local highlight = Instance.new("Highlight")
        highlight.Name = "ESPHighlight"
        highlight.Parent = character
        highlight.FillTransparency = 0.92
        highlight.OutlineTransparency = 0.3
    end
end

-- ========================
-- PERFECT SKILLCHECK
-- ========================
local function doSkillcheck()
    if not skillcheckEnabled and not skillcheckNotPerfectEnabled then return end
    local PG  = LocalPlayer:FindFirstChild("PlayerGui")
    local gui = PG and PG:FindFirstChild("SkillCheckPromptGui")
    local check = gui and gui:FindFirstChild("Check")
    if check and check.Visible then
        local line = check:FindFirstChild("Line")
        local goal = check:FindFirstChild("Goal")
        if line and goal then
            local lr = line.Rotation % 360
            local gr = goal.Rotation % 360
            local gs = (gr + 104) % 360
            local ge = (gr + 114) % 360

            if skillcheckEnabled then
                local inGoal = (gs > ge) and (lr >= gs or lr <= ge) or (lr >= gs and lr <= ge)
                if inGoal then
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                    task.wait(0.01)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end
            elseif skillcheckNotPerfectEnabled then
                local startBuffer = 12
                local endBuffer = 18
                local justAfterWhite = (lr >= ge + startBuffer and lr <= ge + endBuffer)
                if gs > ge then
                    justAfterWhite = (lr >= ge + startBuffer and lr < gs)
                end
                if justAfterWhite then
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                    task.wait(0.01)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end
            end
        end
    end
end

-- ========================
-- MAIN LOOP
-- ========================
RunService.RenderStepped:Connect(function()
    -- Lunge Logic
    if lungeEnabled and isMouseDown and not isMouseOverFrame(MainFrame) then
        pcall(function()
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local holdingTwist = char:FindFirstChild("Twist of Fate")
                local isShooting   = holdingTwist and isRightMouseDown
                if not isShooting then
                    local hrp  = char.HumanoidRootPart
                    local look = hrp.CFrame.LookVector
                    hrp.Velocity = Vector3.new(look.X * lungeSpeed, hrp.Velocity.Y, look.Z * lungeSpeed)
                end
            end
        end)
    end

    -- Skillcheck
    pcall(doSkillcheck)

    -- FOV Logic
    if fovEnabled then Camera.FieldOfView = targetFOV else Camera.FieldOfView = defaultFOV end

    -- Crosshair Logic
    CrosshairGUI.Visible = crosshairEnabled
    if crosshairEnabled then
        if crosshairType == "Dot" then
            CrosshairGUI.Size = UDim2.new(0, 6, 0, 6)
            CrosshairGUI.Position = UDim2.new(0.5, -3, 0.5, -3)
        end
    end

    -- ESP Logic
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local highlight = p.Character:FindFirstChild("ESPHighlight")
            if highlight then
                highlight.Enabled = espEnabled
                highlight.FillColor = isKiller(p) and C.red or C.green
                highlight.OutlineColor = isKiller(p) and C.red or C.green
            else
                applyESP(p.Character, p)
            end
        end
    end
end)

-- ========================
-- INPUT
-- ========================
UserInputService.InputBegan:Connect(function(input, processed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isMouseDown = true
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        isRightMouseDown = true
    end

    if menuVisible and isMouseOverFrame(MainFrame) then
        return
    end

    if processed then return end

    if input.KeyCode == hideMenuKey then
        menuVisible = not menuVisible
        MainFrame.Visible = menuVisible
        UserInputService.MouseIconEnabled = menuVisible
        if menuVisible then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        else
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        end
    elseif input.KeyCode == toggleKey then
        lungeEnabled = not lungeEnabled
        updateLungeUI(lungeEnabled)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isMouseDown = false
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        isRightMouseDown = false
    end
end)

showTab("HOME")
