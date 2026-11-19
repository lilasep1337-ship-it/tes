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

local FRAME_W = isMobile and 300 or 400
local FRAME_H = isMobile and 420 or 440
local SIDE_W  = isMobile and 90  or 120

local TOGGLE_H  = isMobile and 62  or 42
local TOGGLE_W  = isMobile and 56  or 44
local TOGGLE_SH = isMobile and 32  or 26
local TOGGLE_CR = isMobile and 16  or 13
local CIRCLE_SZ = isMobile and 24  or 18
local CIRCLE_CR = isMobile and 12  or 9
local ICON_SZ   = isMobile and 18  or 14
local LABEL_SZ  = isMobile and 13  or 13

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
addCorner(MainFrame, 12)
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
Logo.TextSize               = isMobile and 12 or 18

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
-- MINIMIZE → FLOATING CIRCLE
-- ========================
local minimized = false
local fullSize  = UDim2.new(0, FRAME_W, 0, FRAME_H)
local tweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

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
CircleBtn.Visible                = false
addCorner(CircleBtn, 22)
addStroke(CircleBtn, C.accent, 1.5)

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
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local function toggleMinimize()
    minimized = not minimized
    if minimized then
        local mpos = MainFrame.Position
        TweenService:Create(MainFrame, tweenInfo, {
            Size = UDim2.new(0, FRAME_W, 0, 0)
        }):Play()
        task.delay(0.22, function()
            if minimized then
                MainFrame.Visible  = false
                CircleBtn.Position = UDim2.new(mpos.X.Scale, mpos.X.Offset, mpos.Y.Scale, mpos.Y.Offset)
                CircleBtn.Visible  = true
            end
        end)
    else
        CircleBtn.Visible  = false
        local cpos         = CircleBtn.Position
        MainFrame.Position = UDim2.new(cpos.X.Scale, cpos.X.Offset, cpos.Y.Scale, cpos.Y.Offset)
        MainFrame.Size     = UDim2.new(0, FRAME_W, 0, 0)
        MainFrame.Visible  = true
        TweenService:Create(MainFrame, tweenInfo, { Size = fullSize }):Play()
    end
end

CircleBtn.MouseButton1Click:Connect(toggleMinimize)
CircleBtn.TouchTap:Connect(toggleMinimize)

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Name                   = "MinimizeBtn"
MinimizeBtn.Parent                 = MainFrame
MinimizeBtn.BackgroundColor3       = C.accentDim
MinimizeBtn.BackgroundTransparency = 0
MinimizeBtn.Position               = UDim2.new(1, -38, 0, 4)
MinimizeBtn.Size                   = UDim2.new(0, 32, 0, 32)
MinimizeBtn.Font                   = Enum.Font.GothamBold
MinimizeBtn.Text                   = "−"
MinimizeBtn.TextColor3             = C.white
MinimizeBtn.TextSize               = 20
MinimizeBtn.ZIndex                 = 10
MinimizeBtn.AutoButtonColor        = false
addCorner(MinimizeBtn, 16)
addStroke(MinimizeBtn, C.accent, 1.5)
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
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
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
    f.ScrollBarThickness     = isMobile and 3 or 2
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
    btn.Size             = UDim2.new(1, 0, 0, isMobile and 42 or 32)
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
    local card = createCard(parent, yOffset, TOGGLE_H)

    local hitArea = Instance.new("TextButton")
    hitArea.Parent                 = card
    hitArea.BackgroundTransparency = 1
    hitArea.Size                   = UDim2.new(1, 0, 1, 0)
    hitArea.Text                   = ""
    hitArea.AutoButtonColor        = false
    hitArea.ZIndex                 = 2

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Parent                 = card
    iconLbl.BackgroundTransparency = 1
    iconLbl.Position               = UDim2.new(0, 8, 0, 0)
    iconLbl.Size                   = UDim2.new(0, 24, 1, 0)
    iconLbl.Font                   = Enum.Font.GothamBold
    iconLbl.Text                   = icon
    iconLbl.TextColor3             = C.accentDim
    iconLbl.TextSize               = ICON_SZ

    local label = Instance.new("TextLabel")
    label.Parent                 = card
    label.BackgroundTransparency = 1
    label.Position               = UDim2.new(0, 36, 0, 0)
    label.Size                   = UDim2.new(0.48, 0, 1, 0)
    label.Font                   = Enum.Font.Gotham
    label.Text                   = text
    label.TextColor3             = C.text
    label.TextSize               = LABEL_SZ
    label.TextXAlignment         = Enum.TextXAlignment.Left

    local switchBg = Instance.new("Frame")
    switchBg.Parent           = card
    switchBg.BackgroundColor3 = default and C.accent or C.off
    switchBg.Position         = UDim2.new(1, -(TOGGLE_W + 10), 0.5, -(TOGGLE_SH / 2))
    switchBg.Size             = UDim2.new(0, TOGGLE_W, 0, TOGGLE_SH)
    switchBg.ZIndex           = 3
    addCorner(switchBg, TOGGLE_CR)

    local knob = Instance.new("Frame")
    knob.Parent           = switchBg
    knob.BackgroundColor3 = C.white
    knob.Size             = UDim2.new(0, CIRCLE_SZ, 0, CIRCLE_SZ)
    knob.Position         = default
        and UDim2.new(1, -(CIRCLE_SZ + 4), 0.5, -(CIRCLE_SZ / 2))
        or  UDim2.new(0, 4, 0.5, -(CIRCLE_SZ / 2))
    knob.ZIndex           = 4
    addCorner(knob, CIRCLE_CR)

    local state = default

    local function toggle()
        state = not state
        switchBg.BackgroundColor3 = state and C.accent or C.off
        knob:TweenPosition(
            state
                and UDim2.new(1, -(CIRCLE_SZ + 4), 0.5, -(CIRCLE_SZ / 2))
                or  UDim2.new(0, 4, 0.5, -(CIRCLE_SZ / 2)),
            "Out", "Quad", 0.15, true
        )
        local stroke = card:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = state and C.accent or C.border
            task.delay(0.3, function()
                if stroke and stroke.Parent then
                    stroke.Color = C.border
                end
            end)
        end
        callback(state)
    end

    hitArea.MouseButton1Click:Connect(toggle)
    hitArea.TouchTap:Connect(toggle)

    return function(v)
        state = v
        switchBg.BackgroundColor3 = state and C.accent or C.off
        knob.Position = state
            and UDim2.new(1, -(CIRCLE_SZ + 4), 0.5, -(CIRCLE_SZ / 2))
            or  UDim2.new(0, 4, 0.5, -(CIRCLE_SZ / 2))
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
    local card = createCard(parent, yOffset, isMobile and 56 or 42)
    local label = Instance.new("TextLabel")
    label.Parent                 = card
    label.BackgroundTransparency = 1
    label.Position               = UDim2.new(0, 10, 0, 0)
    label.Size                   = UDim2.new(0.6, 0, 1, 0)
    label.Font                   = Enum.Font.Gotham
    label.Text                   = icon .. " " .. text
    label.TextColor3             = C.text
    label.TextSize               = isMobile and 12 or 13
    label.TextXAlignment         = Enum.TextXAlignment.Left
    local input = Instance.new("TextBox")
    input.Parent           = card
    input.BackgroundColor3 = C.off
    input.Position         = UDim2.new(1, -80, 0.5, -(isMobile and 18 or 13))
    input.Size             = UDim2.new(0, isMobile and 70 or 64, 0, isMobile and 36 or 26)
    input.Font             = Enum.Font.GothamBold
    input.Text             = defaultVal
    input.TextColor3       = C.white
    input.TextSize         = isMobile and 13 or 11
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
BannerTitle.TextSize               = isMobile and 14 or 20
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
    { key = "CIRCLE", desc = "Buka / Tutup Menu" },
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
local updateSkillcheckUI           = createToggle(SurvivorFrame, "✓", "Skillcheck Sempurna",    30,  false, function(v) skillcheckEnabled           = v end)
local updateSkillcheckNotPerfectUI = createToggle(SurvivorFrame, "✗", "Auto Gen (Not Perfect)", 102, false, function(v) skillcheckNotPerfectEnabled = v end)

-- ========================
-- MOVEMENT TAB
-- ========================
createSection(MovementFrame, "MOVEMENT", 5)
local updateLungeUI = createToggle(MovementFrame, "↯", "Lunge Tak Terbatas", 30, false, function(v) lungeEnabled = v end)
createKeybindRow(MovementFrame, "⌨", "Set Tombol Lunge:", toggleKey, 102, function(key) toggleKey = key end)
createLabelInput(MovementFrame, "⚡", "Kecepatan Lunge:", "30", isMobile and 102 or 152, function(txt) lungeSpeed = tonumber(txt) or 30 end)

createSection(MovementFrame, "FOV", isMobile and 168 or 206)
local updateFOVUI = createToggle(MovementFrame, "◎", "Pengubah FOV", isMobile and 196 or 234, false, function(v) fovEnabled = v end)
createLabelInput(MovementFrame, "👁", "Target FOV:", "100", isMobile and 268 or 286, function(txt) targetFOV = tonumber(txt) or 100 end)

-- ========================
-- VISUAL TAB
-- ========================
createSection(VisualFrame, "ESP", 5)
local updateESPUI       = createToggle(VisualFrame, "👁", "ESP Highlight Aktif", 30,  false, function(v) espEnabled       = v end)
local updateCrosshairUI = createToggle(VisualFrame, "⌖", "Custom Crosshair",     102, false, function(v) crosshairEnabled = v end)

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
-- MOBILE TOUCH
-- ========================
if isMobile then
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
-- SKILLCHECK — Space diganti tap tombol sidik jari
-- ========================
local function findSkillcheckNodes(root)
    for _, child in ipairs(root:GetDescendants()) do
        if (child:IsA("Frame") or child:IsA("ImageLabel")) and child.Visible then
            local line = child:FindFirstChild("Line")
            local goal = child:FindFirstChild("Goal")
            if line and goal then
                return line, goal
            end
        end
    end
    return nil, nil
end

local function pressSkill()
    local PG = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not PG then return end

    -- Cari ImageButton bulat visible di PlayerGui, bukan milik GUI kita
    local target = nil
    for _, child in ipairs(PG:GetDescendants()) do
        if child:IsA("ImageButton")
        and child.Visible
        and not child:IsDescendantOf(ScreenGui) then
            local sz = child.AbsoluteSize
            -- bulat = X dan Y hampir sama, ukuran 60-130px
            if sz.X >= 60 and sz.X <= 130 and math.abs(sz.X - sz.Y) < 10 then
                target = child
                break
            end
        end
    end

    if target then
        local pos = target.AbsolutePosition
        local sz  = target.AbsoluteSize
        local cx  = pos.X + sz.X / 2
        local cy  = pos.Y + sz.Y / 2
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true,  game, 1)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
    end
end

local function doSkillcheck()
    if not skillcheckEnabled and not skillcheckNotPerfectEnabled then return end

    local PG = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not PG then return end

    local line, goal = findSkillcheckNodes(PG)
    if not (line and goal) then return end

    local lr = line.Rotation % 360
    local gr = goal.Rotation % 360

    local ZONE_START_OFFSET = 0
    local ZONE_END_OFFSET   = 10

    local gs = (gr + ZONE_START_OFFSET) % 360
    local ge = (gr + ZONE_END_OFFSET)   % 360

    local function inArc(angle, arcStart, arcEnd)
        if arcStart <= arcEnd then
            return angle >= arcStart and angle <= arcEnd
        else
            return angle >= arcStart or angle <= arcEnd
        end
    end

    if skillcheckEnabled then
        if inArc(lr, gs, ge) then
            pressSkill()
        end
    elseif skillcheckNotPerfectEnabled then
        local NP_START = (ge + 5)  % 360
        local NP_END   = (ge + 15) % 360
        if inArc(lr, NP_START, NP_END) then
            pressSkill()
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

    Camera.FieldOfView   = fovEnabled and targetFOV or defaultFOV
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
-- INPUT (desktop)
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
        menuVisible       = not menuVisible
        MainFrame.Visible = menuVisible
        UserInputService.MouseIconEnabled = menuVisible
        UserInputService.MouseBehavior    = menuVisible
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
