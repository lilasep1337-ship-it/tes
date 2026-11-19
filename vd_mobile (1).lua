--[[
    By cuqy puky
    Mobile + Delta Compatible
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
local HttpService         = game:GetService("HttpService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ========================
-- PLATFORM DETECT
-- ========================
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ========================
-- STATE
-- ========================
local lungeEnabled                = false
local espEnabled                  = false
local crosshairEnabled            = false
local fovEnabled                  = false
local skillcheckEnabled           = false
local skillcheckNotPerfectEnabled = false
local menuVisible                 = true

local isMouseDown      = false
local isRightMouseDown = false
local toggleKey        = Enum.KeyCode.P
local hideMenuKey      = Enum.KeyCode.RightControl
local lungeSpeed       = 30
local targetFOV        = 100
local defaultFOV       = Camera.FieldOfView

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
ScreenGui.Name           = "VD_V10_GUI"
ScreenGui.Parent         = CoreGui
ScreenGui.ResetOnSpawn   = false
ScreenGui.DisplayOrder   = 999
ScreenGui.IgnoreGuiInset = true

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
    s.Color     = color or C.border
    s.Thickness = thickness or 1
    s.Parent    = parent
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

local FRAME_W = isMobile and 340 or 400
local FRAME_H = isMobile and 480 or 440
local SIDE_W  = isMobile and 100 or 120

-- ========================
-- MAIN FRAME
-- ========================
local MainFrame = Instance.new("Frame")
MainFrame.Name              = "MainFrame"
MainFrame.Parent            = ScreenGui
MainFrame.BackgroundColor3  = C.bg
MainFrame.BorderSizePixel   = 0
MainFrame.Position          = UDim2.new(0, 10, 0, 10)
MainFrame.Size              = UDim2.new(0, FRAME_W, 0, FRAME_H)
MainFrame.Active            = true
MainFrame.Draggable         = true
MainFrame.ClipsDescendants  = true
local mainCorner = addCorner(MainFrame, 12)
addStroke(MainFrame, C.border, 1.5)
addGradient(MainFrame, Color3.fromRGB(12, 14, 22), Color3.fromRGB(8, 10, 16), 135)

-- ========================
-- SIDEBAR
-- ========================
local Sidebar = Instance.new("Frame")
Sidebar.Name             = "Sidebar"
Sidebar.Parent           = MainFrame
Sidebar.BackgroundColor3 = C.panel
Sidebar.BorderSizePixel  = 0
Sidebar.Size             = UDim2.new(0, SIDE_W, 1, 0)
addStroke(Sidebar, C.border, 1)

local Logo = Instance.new("TextLabel")
Logo.Parent                 = Sidebar
Logo.BackgroundTransparency = 1
Logo.Position               = UDim2.new(0, 0, 0, 15)
Logo.Size                   = UDim2.new(1, 0, 0, 30)
Logo.Font                   = Enum.Font.GothamBlack
Logo.Text                   = "HANGMA"
Logo.TextColor3             = C.accent
Logo.TextSize               = isMobile and 14 or 18

local TabContainer = Instance.new("Frame")
TabContainer.Parent                 = Sidebar
TabContainer.BackgroundTransparency = 1
TabContainer.Position               = UDim2.new(0, 6, 0, 55)
TabContainer.Size                   = UDim2.new(1, -12, 1, -65)
local TabListLayout = Instance.new("UIListLayout")
TabListLayout.Parent  = TabContainer
TabListLayout.Padding = UDim.new(0, 5)

-- ========================
-- CONTENT AREA
-- ========================
local ContentArea = Instance.new("Frame")
ContentArea.Name                   = "ContentArea"
ContentArea.Parent                 = MainFrame
ContentArea.BackgroundTransparency = 1
ContentArea.Position               = UDim2.new(0, SIDE_W, 0, 0)
ContentArea.Size                   = UDim2.new(1, -SIDE_W, 1, 0)

-- ========================
-- MINIMIZE — FLOATING CIRCLE
-- ========================
local minimized = false
local fullSize  = UDim2.new(0, FRAME_W, 0, FRAME_H)
local circleSize = UDim2.new(0, 44, 0, 44)

-- circle button — terpisah dari MainFrame supaya tetap visible saat minimize
local CircleBtn = Instance.new("TextButton")
CircleBtn.Name                   = "CircleBtn"
CircleBtn.Parent                 = ScreenGui
CircleBtn.BackgroundColor3       = C.accentDim
CircleBtn.Position               = UDim2.new(0, 10, 0, 10)
CircleBtn.Size                   = UDim2.new(0, 44, 0, 44)
CircleBtn.Font                   = Enum.Font.GothamBlack
CircleBtn.Text                   = "H"
CircleBtn.TextColor3             = C.white
CircleBtn.TextSize               = 18
CircleBtn.ZIndex                 = 20
CircleBtn.AutoButtonColor        = false
CircleBtn.Visible                = false  -- muncul hanya saat minimized
addCorner(CircleBtn, 22)  -- radius = setengah size → perfect circle
addStroke(CircleBtn, C.accent, 1.5)

-- drag circle button
do
    local dragging, dragStart, startPos
    CircleBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = input.Position
            startPos  = CircleBtn.Position
        end
    end)
    CircleBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.Touch or
            input.UserInputType == Enum.UserInputType.MouseMovement
        ) then
            local delta = input.Position - dragStart
            CircleBtn.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local tweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function toggleMinimize()
    minimized = not minimized

    if minimized then
        -- simpan posisi MainFrame buat posisi circle
        local mpos = MainFrame.Position
        TweenService:Create(MainFrame, tweenInfo, {
            Size = UDim2.new(0, FRAME_W, 0, 0)
        }):Play()
        task.delay(0.22, function()
            if minimized then
                MainFrame.Visible = false
                -- posisi circle ikut posisi pojok kiri atas MainFrame
                CircleBtn.Position = UDim2.new(
                    mpos.X.Scale, mpos.X.Offset,
                    mpos.Y.Scale, mpos.Y.Offset
                )
                CircleBtn.Visible = true
            end
        end)
    else
        CircleBtn.Visible = false
        -- posisi MainFrame ikut posisi circle saat expand
        local cpos = CircleBtn.Position
        MainFrame.Position = UDim2.new(
            cpos.X.Scale, cpos.X.Offset,
            cpos.Y.Scale, cpos.Y.Offset
        )
        MainFrame.Size    = UDim2.new(0, FRAME_W, 0, 0)
        MainFrame.Visible = true
        TweenService:Create(MainFrame, tweenInfo, { Size = fullSize }):Play()
    end
end

CircleBtn.MouseButton1Click:Connect(toggleMinimize)
CircleBtn.TouchTap:Connect(toggleMinimize)

-- tombol minimize kecil di pojok MainFrame
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Name                   = "MinimizeBtn"
MinimizeBtn.Parent                 = MainFrame
MinimizeBtn.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
MinimizeBtn.BackgroundTransparency = 0.6
MinimizeBtn.Position               = UDim2.new(1, -28, 0, 4)
MinimizeBtn.Size                   = UDim2.new(0, 24, 0, 24)
MinimizeBtn.Font                   = Enum.Font.GothamBold
MinimizeBtn.Text                   = "−"
MinimizeBtn.TextColor3             = C.white
MinimizeBtn.TextSize               = 16
MinimizeBtn.ZIndex                 = 10
MinimizeBtn.AutoButtonColor        = false
addCorner(MinimizeBtn, 6)

MinimizeBtn.MouseButton1Click:Connect(toggleMinimize)
MinimizeBtn.TouchTap:Connect(toggleMinimize)

-- ========================
-- DRAG MAIN FRAME
-- ========================
do
    local dragging, dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = input.Position
            startPos  = MainFrame.Position
        end
    end)
    MainFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.Touch or
            input.UserInputType == Enum.UserInputType.MouseMovement
        ) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ========================
-- TAB FRAMES
-- ========================
local function createTabFrame(name)
    local f = Instance.new("ScrollingFrame")
    f.Name                   = name .. "Frame"
    f.Parent                 = ContentArea
    f.BackgroundTransparency = 1
    f.BorderSizePixel        = 0
    f.Size                   = UDim2.new(1, 0, 1, 0)
    f.ScrollBarThickness     = 2
    f.ScrollBarImageColor3   = C.accent
    f.Visible                = false
    f.CanvasSize             = UDim2.new(0, 0, 0, 900)
    f.ScrollingEnabled       = true
    local pad = Instance.new("UIPadding")
    pad.Parent       = f
    pad.PaddingLeft  = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.PaddingTop   = UDim.new(0, 10)
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
    btn.Parent           = TabContainer
    btn.BackgroundColor3 = C.card
    btn.Size             = UDim2.new(1, 0, 0, isMobile and 36 or 32)
    btn.Font             = Enum.Font.GothamBold
    btn.Text             = t.name
    btn.TextColor3       = C.subtext
    btn.TextSize         = isMobile and 9 or 11
    btn.AutoButtonColor  = false
    addCorner(btn, 6)
    addStroke(btn, C.border, 1)
    local function onTab()
        showTab(t.name)
        for _, other in pairs(TabContainer:GetChildren()) do
            if other:IsA("TextButton") then
                other.TextColor3       = C.subtext
                other.BackgroundColor3 = C.card
            end
        end
        btn.TextColor3       = C.white
        btn.BackgroundColor3 = C.accentDim
    end
    btn.MouseButton1Click:Connect(onTab)
    btn.TouchTap:Connect(onTab)
end

-- ========================
-- UI HELPERS
-- ========================
local function createCard(parent, yOffset, height)
    local card = Instance.new("Frame")
    card.Parent           = parent
    card.BackgroundColor3 = C.card
    card.BorderSizePixel  = 0
    card.Position         = UDim2.new(0, 0, 0, yOffset)
    card.Size             = UDim2.new(1, 0, 0, height)
    addCorner(card, 8)
    addStroke(card, C.border, 1)
    return card
end

local function createToggle(parent, icon, text, yOffset, default, callback)
    local h    = isMobile and 48 or 42
    local card = createCard(parent, yOffset, h)
    local iconLbl = Instance.new("TextLabel")
    iconLbl.Parent                 = card
    iconLbl.BackgroundTransparency = 1
    iconLbl.Position               = UDim2.new(0, 8, 0, 0)
    iconLbl.Size                   = UDim2.new(0, 22, 1, 0)
    iconLbl.Font                   = Enum.Font.GothamBold
    iconLbl.Text                   = icon
    iconLbl.TextColor3             = C.accentDim
    iconLbl.TextSize               = isMobile and 16 or 14
    local label = Instance.new("TextLabel")
    label.Parent                 = card
    label.BackgroundTransparency = 1
    label.Position               = UDim2.new(0, 34, 0, 0)
    label.Size                   = UDim2.new(0.5, 0, 1, 0)
    label.Font                   = Enum.Font.Gotham
    label.Text                   = text
    label.TextColor3             = C.text
    label.TextSize               = isMobile and 11 or 13
    label.TextXAlignment         = Enum.TextXAlignment.Left
    local btn = Instance.new("TextButton")
    btn.Parent           = card
    btn.BackgroundColor3 = default and C.accent or C.off
    btn.Position         = UDim2.new(1, -54, 0.5, -13)
    btn.Size             = UDim2.new(0, 44, 0, 26)
    btn.Text             = ""
    btn.AutoButtonColor  = false
    addCorner(btn, 13)
    local circle = Instance.new("Frame")
    circle.Parent           = btn
    circle.BackgroundColor3 = C.white
    circle.Position         = default and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 4, 0.5, -9)
    circle.Size             = UDim2.new(0, 18, 0, 18)
    addCorner(circle, 9)
    local state = default
    local function toggle()
        state = not state
        btn.BackgroundColor3 = state and C.accent or C.off
        circle:TweenPosition(
            state and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 4, 0.5, -9),
            "Out", "Quad", 0.2, true
        )
        callback(state)
    end
    btn.MouseButton1Click:Connect(toggle)
    btn.TouchTap:Connect(toggle)
    return function(v)
        state = v
        btn.BackgroundColor3 = state and C.accent or C.off
        circle.Position = state and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 4, 0.5, -9)
    end
end

local function createKeybindRow(parent, icon, text, currentKey, yOffset, callback)
    if isMobile then return end
    local card = createCard(parent, yOffset, 42)
    local iconLbl = Instance.new("TextLabel")
    iconLbl.Parent                 = card
    iconLbl.BackgroundTransparency = 1
    iconLbl.Position               = UDim2.new(0, 10, 0, 0)
    iconLbl.Size                   = UDim2.new(0, 24, 1, 0)
    iconLbl.Font                   = Enum.Font.GothamBold
    iconLbl.Text                   = icon
    iconLbl.TextColor3             = C.accentDim
    iconLbl.TextSize               = 14
    local label = Instance.new("TextLabel")
    label.Parent                 = card
    label.BackgroundTransparency = 1
    label.Position               = UDim2.new(0, 38, 0, 0)
    label.Size                   = UDim2.new(0.45, 0, 1, 0)
    label.Font                   = Enum.Font.Gotham
    label.Text                   = text
    label.TextColor3             = C.text
    label.TextSize               = 13
    label.TextXAlignment         = Enum.TextXAlignment.Left
    local bindBtn = Instance.new("TextButton")
    bindBtn.Parent           = card
    bindBtn.BackgroundColor3 = C.off
    bindBtn.Position         = UDim2.new(1, -72, 0.5, -13)
    bindBtn.Size             = UDim2.new(0, 64, 0, 26)
    bindBtn.Font             = Enum.Font.GothamBold
    bindBtn.Text             = currentKey.Name
    bindBtn.TextColor3       = C.accent
    bindBtn.TextSize         = 11
    bindBtn.AutoButtonColor  = false
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

local function createLabelInput(parent, icon, text, defaultVal, yOffset, callback)
    local card = createCard(parent, yOffset, isMobile and 48 or 42)
    local label = Instance.new("TextLabel")
    label.Parent                 = card
    label.BackgroundTransparency = 1
    label.Position               = UDim2.new(0, 10, 0, 0)
    label.Size                   = UDim2.new(0.6, 0, 1, 0)
    label.Font                   = Enum.Font.Gotham
    label.Text                   = icon .. " " .. text
    label.TextColor3             = C.text
    label.TextSize               = isMobile and 11 or 13
    label.TextXAlignment         = Enum.TextXAlignment.Left
    local input = Instance.new("TextBox")
    input.Parent           = card
    input.BackgroundColor3 = C.off
    input.Position         = UDim2.new(1, -74, 0.5, -13)
    input.Size             = UDim2.new(0, 64, 0, 26)
    input.Font             = Enum.Font.GothamBold
    input.Text             = defaultVal
    input.TextColor3       = C.white
    input.TextSize         = 11
    input.ClearTextOnFocus = false
    addCorner(input, 6)
    addStroke(input, C.border, 1)
    input.FocusLost:Connect(function() callback(input.Text) end)
    return input
end

local function createSection(parent, text, yOffset)
    local lbl = Instance.new("TextLabel")
    lbl.Parent                 = parent
    lbl.BackgroundTransparency = 1
    lbl.Position               = UDim2.new(0, 4, 0, yOffset)
    lbl.Size                   = UDim2.new(1, -8, 0, 22)
    lbl.Font                   = Enum.Font.GothamBold
    lbl.Text                   = text
    lbl.TextColor3             = C.accent
    lbl.TextSize               = 11
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    local line = Instance.new("Frame")
    line.Parent                 = lbl
    line.BackgroundColor3       = C.accent
    line.Size                   = UDim2.new(1, 0, 0, 1)
    line.Position               = UDim2.new(0, 0, 1, -2)
    line.BorderSizePixel        = 0
    line.BackgroundTransparency = 0.6
end

-- ========================
-- HOME TAB
-- ========================
local BannerCard = createCard(HomeFrame, 5, 80)
BannerCard.BackgroundColor3 = C.panel
addGradient(BannerCard, Color3.fromRGB(0, 60, 80), Color3.fromRGB(12, 14, 22), 135)
local BannerTitle = Instance.new("TextLabel")
BannerTitle.Parent                 = BannerCard
BannerTitle.BackgroundTransparency = 1
BannerTitle.Position               = UDim2.new(0, 14, 0, 8)
BannerTitle.Size                   = UDim2.new(1, -14, 0, 30)
BannerTitle.Font                   = Enum.Font.GothamBlack
BannerTitle.Text                   = "BY CUQY PUQY"
BannerTitle.TextColor3             = C.accent
BannerTitle.TextSize               = isMobile and 16 or 20
BannerTitle.TextXAlignment         = Enum.TextXAlignment.Left
local BannerSub = Instance.new("TextLabel")
BannerSub.Parent                 = BannerCard
BannerSub.BackgroundTransparency = 1
BannerSub.Position               = UDim2.new(0, 14, 0, 36)
BannerSub.Size                   = UDim2.new(1, -14, 0, 18)
BannerSub.Font                   = Enum.Font.Gotham
BannerSub.Text                   = "MENJADI HANGMA"
BannerSub.TextColor3             = C.subtext
BannerSub.TextSize               = 11
BannerSub.TextXAlignment         = Enum.TextXAlignment.Left

createSection(HomeFrame, "KEYBIND DEFAULT", 93)
local keybinds = isMobile and {
    { key = "TAP TOGGLE", desc = "Toggle Lunge (Mobile Button)" },
    { key = "TAP MENU",   desc = "Sembunyikan / Tampilkan Menu" },
} or {
    { key = "R-CTRL", desc = "Sembunyikan / Tampilkan Menu" },
    { key = "P",      desc = "Toggle Infinite Lunge"       },
}
for i, kb in ipairs(keybinds) do
    local kCard = createCard(HomeFrame, 118 + (i-1) * 48, 40)
    local kLabel = Instance.new("TextLabel")
    kLabel.Parent                 = kCard
    kLabel.BackgroundTransparency = 1
    kLabel.Position               = UDim2.new(0, 10, 0, 0)
    kLabel.Size                   = UDim2.new(0.6, 0, 1, 0)
    kLabel.Font                   = Enum.Font.Gotham
    kLabel.Text                   = kb.desc
    kLabel.TextColor3             = C.text
    kLabel.TextSize               = 11
    kLabel.TextXAlignment         = Enum.TextXAlignment.Left
    local kBadge = Instance.new("TextLabel")
    kBadge.Parent           = kCard
    kBadge.BackgroundColor3 = C.off
    kBadge.Position         = UDim2.new(1, -84, 0.5, -11)
    kBadge.Size             = UDim2.new(0, 74, 0, 22)
    kBadge.Font             = Enum.Font.GothamBold
    kBadge.Text             = kb.key
    kBadge.TextColor3       = C.accent
    kBadge.TextSize         = 9
    addCorner(kBadge, 4)
    addStroke(kBadge, C.border, 1)
end

-- ========================
-- SURVIVOR TAB
-- ========================
createSection(SurvivorFrame, "SKILLCHECK", 5)
local updateSkillcheckUI           = createToggle(SurvivorFrame, "✓", "Skillcheck Sempurna",    30, false, function(v) skillcheckEnabled           = v end)
local updateSkillcheckNotPerfectUI = createToggle(SurvivorFrame, "✗", "Auto Gen (Not Perfect)", 84, false, function(v) skillcheckNotPerfectEnabled = v end)

-- ========================
-- MOVEMENT TAB
-- ========================
createSection(MovementFrame, "MOVEMENT", 5)
local updateLungeUI = createToggle(MovementFrame, "↯", "Lunge Tak Terbatas", 30, false, function(v) lungeEnabled = v end)
createKeybindRow(MovementFrame, "⌨", "Set Tombol Lunge:", toggleKey, 84, function(key) toggleKey = key end)
createLabelInput(MovementFrame, "⚡", "Kecepatan Lunge:", "30", isMobile and 84 or 132, function(txt) lungeSpeed = tonumber(txt) or 30 end)

createSection(MovementFrame, "FOV", isMobile and 142 or 188)
local updateFOVUI = createToggle(MovementFrame, "◎", "Pengubah FOV", isMobile and 167 or 213, false, function(v) fovEnabled = v end)
createLabelInput(MovementFrame, "👁", "Target FOV:", "100", isMobile and 221 or 267, function(txt) targetFOV = tonumber(txt) or 100 end)

-- ========================
-- VISUAL TAB
-- ========================
createSection(VisualFrame, "ESP", 5)
local updateESPUI       = createToggle(VisualFrame, "👁", "ESP Highlight Aktif", 30, false, function(v) espEnabled       = v end)
local updateCrosshairUI = createToggle(VisualFrame, "⌖", "Custom Crosshair",     84, false, function(v) crosshairEnabled = v end)

-- ========================
-- CROSSHAIR GUI
-- ========================
local CrosshairGUI = Instance.new("Frame")
CrosshairGUI.Name              = "CustomCrosshair"
CrosshairGUI.Parent            = ScreenGui
CrosshairGUI.BackgroundColor3  = C.red
CrosshairGUI.BorderSizePixel   = 0
CrosshairGUI.Size              = UDim2.new(0, 6, 0, 6)
CrosshairGUI.Position          = UDim2.new(0.5, -3, 0.5, -3)
CrosshairGUI.Visible           = false
addCorner(CrosshairGUI, 3)

-- ========================
-- MOBILE BUTTONS
-- ========================
if isMobile then
    local hideBtn = Instance.new("TextButton")
    hideBtn.Parent           = ScreenGui
    hideBtn.BackgroundColor3 = C.accentDim
    hideBtn.Position         = UDim2.new(0, 10, 1, -60)
    hideBtn.Size             = UDim2.new(0, 70, 0, 44)
    hideBtn.Font             = Enum.Font.GothamBold
    hideBtn.Text             = "MENU"
    hideBtn.TextColor3       = C.white
    hideBtn.TextSize         = 13
    hideBtn.ZIndex           = 10
    addCorner(hideBtn, 8)
    hideBtn.TouchTap:Connect(function()
        menuVisible = not menuVisible
        MainFrame.Visible = menuVisible
    end)

    local lungeBtn = Instance.new("TextButton")
    lungeBtn.Parent           = ScreenGui
    lungeBtn.BackgroundColor3 = C.off
    lungeBtn.Position         = UDim2.new(0, 90, 1, -60)
    lungeBtn.Size             = UDim2.new(0, 70, 0, 44)
    lungeBtn.Font             = Enum.Font.GothamBold
    lungeBtn.Text             = "LUNGE"
    lungeBtn.TextColor3       = C.accent
    lungeBtn.TextSize         = 13
    lungeBtn.ZIndex           = 10
    addCorner(lungeBtn, 8)
    addStroke(lungeBtn, C.border, 1)
    lungeBtn.TouchTap:Connect(function()
        lungeEnabled = not lungeEnabled
        updateLungeUI(lungeEnabled)
        lungeBtn.BackgroundColor3 = lungeEnabled and C.accent or C.off
        lungeBtn.TextColor3       = lungeEnabled and C.bg    or C.accent
    end)

    UserInputService.TouchStarted:Connect(function(touch)
        local vp = workspace.CurrentCamera.ViewportSize
        if touch.Position.X > vp.X * 0.5 and touch.Position.Y > vp.Y * 0.6 then
            isMouseDown = true
        end
    end)
    UserInputService.TouchEnded:Connect(function()
        isMouseDown = false
    end)
end

-- ========================
-- ESP LOGIC
-- ========================
local function applyESP(character)
    if not character:FindFirstChild("ESPHighlight") then
        local highlight = Instance.new("Highlight")
        highlight.Name                = "ESPHighlight"
        highlight.Parent              = character
        highlight.FillTransparency    = 0.92
        highlight.OutlineTransparency = 0.3
    end
end

-- ========================
-- PERFECT SKILLCHECK
-- ========================
local function doSkillcheck()
    if not skillcheckEnabled and not skillcheckNotPerfectEnabled then return end
    local PG    = LocalPlayer:FindFirstChild("PlayerGui")
    local gui   = PG and PG:FindFirstChild("SkillCheckPromptGui")
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
                    VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.Space, false, game)
                    task.wait(0.01)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end
            elseif skillcheckNotPerfectEnabled then
                local justAfterWhite = (lr >= ge + 12 and lr <= ge + 18)
                if gs > ge then
                    justAfterWhite = (lr >= ge + 12 and lr < gs)
                end
                if justAfterWhite then
                    VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.Space, false, game)
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

    pcall(doSkillcheck)

    Camera.FieldOfView = fovEnabled and targetFOV or defaultFOV

    CrosshairGUI.Visible = crosshairEnabled and not isMobile

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local highlight = p.Character:FindFirstChild("ESPHighlight")
            if highlight then
                highlight.Enabled      = espEnabled
                highlight.FillColor    = isKiller(p) and C.red or C.green
                highlight.OutlineColor = isKiller(p) and C.red or C.green
            else
                applyESP(p.Character)
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

    if menuVisible and isMouseOverFrame(MainFrame) then return end
    if processed then return end

    if input.KeyCode == hideMenuKey then
        menuVisible = not menuVisible
        MainFrame.Visible = menuVisible
        UserInputService.MouseIconEnabled = menuVisible
        UserInputService.MouseBehavior = menuVisible
            and Enum.MouseBehavior.Default
            or  Enum.MouseBehavior.LockCenter
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