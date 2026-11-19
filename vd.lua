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
local espEnabled        = false
local crosshairEnabled  = false
local fovEnabled        = false
local skillcheckEnabled = false
local skillcheckNotPerfectEnabled = false
local menuVisible       = true

local isMouseDown        = false
local isRightMouseDown   = false
local hideMenuKey        = Enum.KeyCode.RightControl
local targetFOV     = 100
local defaultFOV    = Camera.FieldOfView
local espPallet     = false
local espGenerator  = false

-- ========================
-- AUTO SAVE / LOAD CONFIG
-- ========================
local CONFIG_FILE = "HANGMA_PC_CONFIG.json"
local Config = {}

local function loadConfig()
    local ok, data = pcall(function()
        if isfile and isfile(CONFIG_FILE) then
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end
    end)
    if ok and type(data) == "table" then
        return data
    end
    return {}
end

local function saveConfig()
    pcall(function()
        if writefile then
            writefile(CONFIG_FILE, HttpService:JSONEncode({
                espEnabled = espEnabled,
                espPallet = espPallet,
                espGenerator = espGenerator,
                crosshairEnabled = crosshairEnabled,
                fovEnabled = fovEnabled,
                skillcheckEnabled = skillcheckEnabled,
                skillcheckNotPerfectEnabled = skillcheckNotPerfectEnabled,
                targetFOV = targetFOV,
            }))
        end
    end)
end

Config = loadConfig()
espEnabled = Config.espEnabled == true
crosshairEnabled = Config.crosshairEnabled == true
fovEnabled = Config.fovEnabled == true
skillcheckEnabled = Config.skillcheckEnabled == true
skillcheckNotPerfectEnabled = Config.skillcheckNotPerfectEnabled == true
targetFOV = tonumber(Config.targetFOV) or 100

-- Object ESP state
espPallet = Config.espPallet == true
espGenerator = Config.espGenerator == true
local objectHighlights = {}
local generatorBillboards = {}
local lastObjectESPUpdate = 0

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
local VisualFrame   = createTabFrame("Visual")
local LainnyaFrame  = createTabFrame("Lainnya")

local tabs = {
    { name = "HOME",     frame = HomeFrame     },
    { name = "SURVIVOR", frame = SurvivorFrame },
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
local updateSkillcheckUI = createToggle(SurvivorFrame, "✓", "Skillcheck Sempurna", 30, skillcheckEnabled, function(v) skillcheckEnabled = v; saveConfig() end)
local updateSkillcheckNotPerfectUI = createToggle(SurvivorFrame, "✗", "Auto Gen (Not Perfect)", 78, skillcheckNotPerfectEnabled, function(v) skillcheckNotPerfectEnabled = v; saveConfig() end)

-- ========================
-- VISUAL TAB
-- ========================
createSection(VisualFrame, "ESP", 5)
local updateESPUI = createToggle(VisualFrame, "👁", "ESP Highlight Aktif", 30, espEnabled, function(v)
    espEnabled = v
    saveConfig()
    -- Kalau dimatiin, langsung disable semua highlight yang ada
    if not v then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local h = p.Character:FindFirstChild("ESPHighlight")
                if h then h.Enabled = false end
            end
        end
    end
end)

local updateESPPalletUI = createToggle(VisualFrame, "🪵", "ESP Pallet", 78, espPallet, function(v)
    espPallet = v
    saveConfig()
    if not v then
        for obj in pairs(objectHighlights) do
            if obj and obj.Parent and (obj.Name == "Palletwrong" or obj.Name == "Pallet") then
                objectHighlights[obj]:Destroy()
                objectHighlights[obj] = nil
            end
        end
    end
end)

local updateESPGeneratorUI = createToggle(VisualFrame, "⚙", "ESP Generator + %", 126, espGenerator, function(v)
    espGenerator = v
    saveConfig()
    if not v then
        for obj, billboard in pairs(generatorBillboards) do
            if billboard and billboard.Parent then billboard:Destroy() end
            generatorBillboards[obj] = nil
        end
        for obj, highlight in pairs(objectHighlights) do
            if obj and obj.Parent and obj.Name == "Generator" then
                highlight:Destroy()
                objectHighlights[obj] = nil
            end
        end
    end
end)

createSection(VisualFrame, "FOV", 185)
local updateFOVUI = createToggle(VisualFrame, "◎", "Pengubah FOV", 210, fovEnabled, function(v) fovEnabled = v; saveConfig() end)
local fovInput = createLabelInput(VisualFrame, "👁", "Target FOV:", tostring(targetFOV), 258, function(txt) targetFOV = tonumber(txt) or 100; saveConfig() end)

createSection(VisualFrame, "CROSSHAIR", 313)
local updateCrosshairUI = createToggle(VisualFrame, "⌖", "Custom Crosshair", 338, crosshairEnabled, function(v) crosshairEnabled = v; saveConfig() end)

-- ========================
-- LAINNYA: AUTO SAVE / RESET
-- ========================
createSection(LainnyaFrame, "CONFIGURATION", 5)
local configStatus = createCard(LainnyaFrame, 30, 42)
local configStatusLabel = Instance.new("TextLabel")
configStatusLabel.Parent = configStatus
configStatusLabel.BackgroundTransparency = 1
configStatusLabel.Position = UDim2.new(0, 10, 0, 0)
configStatusLabel.Size = UDim2.new(1, -20, 1, 0)
configStatusLabel.Font = Enum.Font.Gotham
configStatusLabel.Text = "Auto Save: AKTIF"
configStatusLabel.TextColor3 = C.green
configStatusLabel.TextSize = 12
configStatusLabel.TextXAlignment = Enum.TextXAlignment.Left

local resetConfigCard = createCard(LainnyaFrame, 82, 44)
local resetConfigButton = Instance.new("TextButton")
resetConfigButton.Parent = resetConfigCard
resetConfigButton.BackgroundTransparency = 1
resetConfigButton.Size = UDim2.new(1, 0, 1, 0)
resetConfigButton.Font = Enum.Font.GothamBold
resetConfigButton.Text = "Reset Setting"
resetConfigButton.TextColor3 = C.red
resetConfigButton.TextSize = 12
resetConfigButton.AutoButtonColor = false

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
-- ESP LOGIC — Solara-safe
-- Pakai tabel tracking buat hindari double-instance
-- dan re-apply otomatis kalau character respawn
-- ========================
local espConnections = {}

local function cleanESPHighlight(character)
    -- Hapus semua ESPHighlight lama (jaga-jaga double instance di Solara)
    for _, obj in pairs(character:GetChildren()) do
        if obj.Name == "ESPHighlight" then
            obj:Destroy()
        end
    end
end

local function applyESP(player)
    local character = player.Character
    if not character then return end

    cleanESPHighlight(character)

    local highlight = Instance.new("Highlight")
    highlight.Name               = "ESPHighlight"
    highlight.FillTransparency   = 0.92
    highlight.OutlineTransparency = 0.3
    highlight.Enabled            = espEnabled
    highlight.FillColor          = isKiller(player) and C.red or C.green
    highlight.OutlineColor       = isKiller(player) and C.red or C.green
    highlight.Parent             = character
end

local function setupPlayerESP(player)
    -- Lepas koneksi lama kalau ada
    if espConnections[player] then
        espConnections[player]:Disconnect()
        espConnections[player] = nil
    end

    if player.Character then
        applyESP(player)
    end

    -- Auto re-apply tiap respawn
    espConnections[player] = player.CharacterAdded:Connect(function(char)
        task.wait(0.5) -- tunggu character fully loaded
        applyESP(player)
    end)
end

local function teardownPlayerESP(player)
    if espConnections[player] then
        espConnections[player]:Disconnect()
        espConnections[player] = nil
    end
    if player.Character then
        cleanESPHighlight(player.Character)
    end
end

-- Setup ESP untuk semua player yang sudah ada
for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        setupPlayerESP(p)
    end
end

-- Setup ESP untuk player baru masuk
Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then
        setupPlayerESP(p)
    end
end)

-- Bersihkan koneksi kalau player keluar
Players.PlayerRemoving:Connect(function(p)
    espConnections[p] = nil
end)

-- ========================
-- OBJECT ESP: PALLET + GENERATOR PROGRESS
-- ========================
local function getGameValue(obj, names)
    for _, name in ipairs(names) do
        local ok, value = pcall(function()
            local attr = obj:GetAttribute(name)
            if attr ~= nil then return attr end
            local child = obj:FindFirstChild(name, true)
            return child and child.Value or nil
        end)
        if ok and value ~= nil then return value end
    end
    return nil
end

local function getGeneratorPercent(generator)
    local value = getGameValue(generator, {"Progress", "RepairProgress", "GeneratorProgress", "Repair", "Value", "GenValue"})
    value = tonumber(value)
    if not value then return nil end
    -- Dukungan nilai 0..1 maupun 0..100.
    if value >= 0 and value <= 1 then value = value * 100 end
    return math.clamp(math.floor(value + 0.5), 0, 100)
end

local function removeObjectESP(obj)
    local highlight = objectHighlights[obj]
    if highlight then pcall(function() highlight:Destroy() end) end
    objectHighlights[obj] = nil
    local billboard = generatorBillboards[obj]
    if billboard then pcall(function() billboard:Destroy() end) end
    generatorBillboards[obj] = nil
end

local function applyObjectHighlight(obj, color)
    if not obj or not obj.Parent then return end
    local highlight = objectHighlights[obj]
    if not highlight or not highlight.Parent then
        highlight = Instance.new("Highlight")
        highlight.Name = "HANGMA_ObjectESP"
        highlight.Adornee = obj
        highlight.FillTransparency = 0.55
        highlight.OutlineTransparency = 0
        highlight.Parent = obj
        objectHighlights[obj] = highlight
    end
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.Enabled = true
end

local function updateGeneratorBillboard(generator, percent)
    if not generator or not generator.Parent then return end
    local billboard = generatorBillboards[generator]
    if not billboard or not billboard.Parent then
        local part = generator:IsA("BasePart") and generator or generator:FindFirstChildWhichIsA("BasePart", true)
        if not part then return end
        billboard = Instance.new("BillboardGui")
        billboard.Name = "HANGMA_GeneratorPercent"
        billboard.AlwaysOnTop = true
        billboard.Size = UDim2.new(0, 68, 0, 18)
        billboard.StudsOffset = Vector3.new(0, 3.5, 0)
        billboard.Adornee = part
        billboard.Parent = generator
        local label = Instance.new("TextLabel")
        label.Name = "Percent"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextScaled = false
        label.TextSize = 11
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.new(0, 0, 0)
        label.Parent = billboard
        generatorBillboards[generator] = billboard
    end
    local label = billboard:FindFirstChild("Percent")
    if label then
        label.Text = percent and (tostring(percent) .. "%") or "GEN"
        label.TextColor3 = percent and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(180, 100, 255)
    end
end

local function updateObjectESP()
    local now = tick()
    if now - lastObjectESPUpdate < 0.25 then return end
    lastObjectESPUpdate = now
    local map = Workspace:FindFirstChild("Map")
    local seenPallets, seenGenerators = {}, {}
    -- Pallet dapat berada langsung di Workspace atau di dalam Map.
    if espPallet then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if (obj:IsA("Model") or obj:IsA("BasePart"))
                and (obj.Name == "Palletwrong" or obj.Name == "Pallet") then
                seenPallets[obj] = true
                applyObjectHighlight(obj, Color3.fromRGB(74, 255, 181))
            end
        end
    end
    if espGenerator and map then
        for _, obj in ipairs(map:GetDescendants()) do
            if obj:IsA("Model") and obj.Name == "Generator" then
                seenGenerators[obj] = true
                applyObjectHighlight(obj, Color3.fromRGB(180, 100, 255))
                updateGeneratorBillboard(obj, getGeneratorPercent(obj))
            end
        end
    end
    for obj in pairs(objectHighlights) do
        local keep = (espPallet and seenPallets[obj]) or (espGenerator and seenGenerators[obj])
        if not keep then removeObjectESP(obj) end
    end
    for obj in pairs(generatorBillboards) do
        if not seenGenerators[obj] then removeObjectESP(obj) end
    end
end

-- Reset hanya mengembalikan setting script, tidak mengubah setting game.
local function resetConfig()
    espEnabled = false
    espPallet = false
    espGenerator = false
    crosshairEnabled = false
    fovEnabled = false
    skillcheckEnabled = false
    skillcheckNotPerfectEnabled = false
    targetFOV = 100

    updateESPUI(false)
    updateESPPalletUI(false)
    updateESPGeneratorUI(false)
    updateFOVUI(false)
    updateCrosshairUI(false)
    updateSkillcheckUI(false)
    updateSkillcheckNotPerfectUI(false)
    fovInput.Text = "100"
    Camera.FieldOfView = defaultFOV

    for obj, highlight in pairs(objectHighlights) do
        pcall(function() highlight:Destroy() end)
        objectHighlights[obj] = nil
    end
    for obj, billboard in pairs(generatorBillboards) do
        pcall(function() billboard:Destroy() end)
        generatorBillboards[obj] = nil
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            cleanESPHighlight(player.Character)
        end
    end
    saveConfig()
    configStatusLabel.Text = "Setting di-reset • Auto Save: AKTIF"
    configStatusLabel.TextColor3 = C.accent
    task.delay(2, function()
        if configStatusLabel and configStatusLabel.Parent then
            configStatusLabel.Text = "Auto Save: AKTIF"
            configStatusLabel.TextColor3 = C.green
        end
    end)
end
resetConfigButton.MouseButton1Click:Connect(resetConfig)

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
    -- Skillcheck
    pcall(doSkillcheck)

    -- FOV Logic
    if fovEnabled then
        Camera.FieldOfView = targetFOV
    else
        Camera.FieldOfView = defaultFOV
    end

    -- Crosshair Logic
    CrosshairGUI.Visible = crosshairEnabled

    -- ESP object terpisah: pallet dan generator + persen
    pcall(updateObjectESP)

    -- ESP update warna tiap frame (team bisa berubah mid-game)
    if espEnabled then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local h = p.Character:FindFirstChild("ESPHighlight")
                if h then
                    h.Enabled      = true
                    h.FillColor    = isKiller(p) and C.red or C.green
                    h.OutlineColor = isKiller(p) and C.red or C.green
                elseif espEnabled then
                    -- Highlight hilang (misalnya kena destroy), re-apply
                    applyESP(p)
                end
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
        if menuVisible then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        else
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        end
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
-- Pastikan konfigurasi yang dimuat langsung tersimpan dalam format terbaru.
saveConfig()
