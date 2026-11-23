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
local arrowVeilEnabled  = false
local crosshairEnabled  = false
local fovEnabled        = false
local fullBrightEnabled = false
local aimZoomActive     = false
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
                arrowVeilEnabled = arrowVeilEnabled,
                espPallet = espPallet,
                espGenerator = espGenerator,
                crosshairEnabled = crosshairEnabled,
                fovEnabled = fovEnabled,
                fullBrightEnabled = fullBrightEnabled,
                skillcheckEnabled = skillcheckEnabled,
                skillcheckNotPerfectEnabled = skillcheckNotPerfectEnabled,
                targetFOV = targetFOV,
            }))
        end
    end)
end

Config = loadConfig()
espEnabled = Config.espEnabled == true
arrowVeilEnabled = Config.arrowVeilEnabled == true
crosshairEnabled = Config.crosshairEnabled == true
fovEnabled = Config.fovEnabled == true
fullBrightEnabled = Config.fullBrightEnabled == true
skillcheckEnabled = Config.skillcheckEnabled == true
skillcheckNotPerfectEnabled = Config.skillcheckNotPerfectEnabled == true
targetFOV = tonumber(Config.targetFOV) or 100

-- Snapshot current Lighting values so Full Bright can restore them on reset.
local fullBrightValues = {
    Brightness = 3,
    ClockTime = 14,
    FogEnd = 100000,
    GlobalShadows = false,
    Ambient = Color3.fromRGB(185, 185, 185),
    OutdoorAmbient = Color3.fromRGB(185, 185, 185),
    ExposureCompensation = 0.25,
    EnvironmentDiffuseScale = 1,
    EnvironmentSpecularScale = 1,
}
local originalLighting = {}
for property in pairs(fullBrightValues) do
    local ok, value = pcall(function() return Lighting[property] end)
    if ok then originalLighting[property] = value end
end

local function applyFullBright(enabled)
    for property, brightValue in pairs(fullBrightValues) do
        local value
        if enabled then
            value = brightValue
        else
            value = originalLighting[property]
        end
        if value ~= nil then
            pcall(function() Lighting[property] = value end)
        end
    end
end

if fullBrightEnabled then
    applyFullBright(true)
end

local lastFullBrightApply = 0

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
    local teamName = player.Team and string.lower(player.Team.Name) or ""
    if teamName:find("killer", 1, true)
        or teamName:find("slasher", 1, true)
        or teamName:find("traitor", 1, true) then
        return true
    end
    local character = player.Character
    local morphed = character and character:GetAttribute("MorphedKiller")
    return type(morphed) == "string" and morphed ~= ""
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
    orange    = Color3.fromRGB(255, 160, 40),  -- warna trap
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

local KillerPopup = Instance.new("Frame")
KillerPopup.Name = "KillerTypePopup"
KillerPopup.Parent = ScreenGui
KillerPopup.AnchorPoint = Vector2.new(1, 0)
KillerPopup.Position = UDim2.new(1, -12, 0, 12)
KillerPopup.Size = UDim2.new(0, 190, 0, 40)
KillerPopup.BackgroundColor3 = C.panel
KillerPopup.BorderSizePixel = 0
KillerPopup.ZIndex = 50
addCorner(KillerPopup, 8)
local killerPopupStroke = addStroke(KillerPopup, C.red, 1.25)
killerPopupStroke.Transparency = 0.1
local KillerInfoLabel = Instance.new("TextLabel")
KillerInfoLabel.Name = "KillerTypeLabel"
KillerInfoLabel.Parent = KillerPopup
KillerInfoLabel.BackgroundTransparency = 1
KillerInfoLabel.Position = UDim2.new(0, 10, 0, 0)
KillerInfoLabel.Size = UDim2.new(1, -20, 1, 0)
KillerInfoLabel.Font = Enum.Font.GothamBold
KillerInfoLabel.Text = "JENIS KILLER: MENCARI..."
KillerInfoLabel.TextColor3 = C.subtext
KillerInfoLabel.TextSize = 11
KillerInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
KillerInfoLabel.TextTruncate = Enum.TextTruncate.AtEnd
KillerInfoLabel.ZIndex = 51

local function readStringAttribute(instance, names)
    if not instance then return nil end
    for _, name in ipairs(names) do
        local value = instance:GetAttribute(name)
        if type(value) == "string" and value ~= "" then
            return value
        end
    end
    return nil
end

local KnownKillerTypes = {
    veil = "Veil",
    butcher = "Butcher",
    stalker = "Stalker",
    masked = "Masked",
    abysswalker = "Abysswalker",
    hidden = "Hidden",
    cure = "Cure",
    jeff = "Jeff",
}

local function knownKillerType(value)
    if type(value) ~= "string" then return nil end
    return KnownKillerTypes[string.lower(value)]
end

local function getKillerType(player)
    local typeNames = {
        "SelectedKiller", "MorphedKiller", "KillerType", "KillerName",
        "KillerCharacter", "CharacterName", "Archetype", "Class"
    }
    local character = player.Character

    local value = readStringAttribute(player, typeNames)
        or readStringAttribute(character, typeNames)
    if value and value ~= "Killer" and value ~= "Slasher" then
        return value
    end

    for _, container in ipairs({ player, character }) do
        if container then
            local attributes = container:GetAttributes()
            for _, attributeValue in pairs(attributes) do
                local known = knownKillerType(attributeValue)
                if known then return known end
            end
        end
    end

    if character then
        local characterName = character.Name
        if characterName ~= player.Name and characterName ~= "Character" then
            return characterName
        end
        for _, object in ipairs(character:GetChildren()) do
            if object:IsA("Tool") and object.Name ~= "" then
                return object.Name
            end
        end
        for _, object in ipairs(character:GetDescendants()) do
            local known = knownKillerType(object.Name)
            if known then return known end
        end
    end

    for _, container in ipairs({ player, character }) do
        if container then
            for _, object in ipairs(container:GetDescendants()) do
                if object:IsA("StringValue") then
                    local lowerName = string.lower(object.Name)
                    if lowerName:find("killer", 1, true)
                        or lowerName:find("character", 1, true)
                        or lowerName:find("class", 1, true) then
                        if object.Value ~= "" and object.Value ~= "Killer" then
                            return object.Value
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function isKillerRoleValue(value)
    if type(value) ~= "string" then return false end
    value = string.lower(value)
    return value == "killer" or value == "slasher" or value == "traitor"
        or value:find("killer", 1, true) ~= nil
end

local lastReplicatedKillerScan = 0
local cachedReplicatedKillerType = nil
local function getReplicatedKillerType()
    local now = tick()
    if now - lastReplicatedKillerScan < 2 then return cachedReplicatedKillerType end
    lastReplicatedKillerScan = now
    cachedReplicatedKillerType = nil
    local valueNames = {
        killertype = true, killername = true, killercharacter = true,
        charactername = true, selectedkiller = true, morphedkiller = true,
        killerclass = true, currentkiller = true,
    }
    local containers = { workspace, ReplicatedStorage, LocalPlayer, LocalPlayer:FindFirstChildOfClass("PlayerGui") }
    for _, container in ipairs(containers) do
        if container then
            for _, object in ipairs(container:GetDescendants()) do
                local objectName = string.lower(object.Name)
                if object:IsA("StringValue") and valueNames[objectName] then
                    local value = object.Value
                    if value ~= "" and not isKillerRoleValue(value) then
                        cachedReplicatedKillerType = value
                        return cachedReplicatedKillerType
                    end
                end
                local attributes = object:GetAttributes()
                for attributeName, attributeValue in pairs(attributes) do
                    local lowerName = string.lower(attributeName)
                    if valueNames[lowerName] and type(attributeValue) == "string"
                        and attributeValue ~= "" and not isKillerRoleValue(attributeValue) then
                        cachedReplicatedKillerType = attributeValue
                        return cachedReplicatedKillerType
                    end
                end
            end
        end
    end
    return cachedReplicatedKillerType
end

local function updateKillerInfo()
    local found = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isKiller(player) then
            local killerType = getKillerType(player)
            if killerType then
                table.insert(found, killerType)
            end
        end
    end
    if #found == 0 then
        local replicatedType = getReplicatedKillerType()
        if replicatedType then table.insert(found, replicatedType) end
    end
    if #found > 0 then
        KillerInfoLabel.Text = "JENIS KILLER: " .. table.concat(found, ", ")
        KillerInfoLabel.TextColor3 = C.red
    else
        KillerInfoLabel.Text = "JENIS KILLER: BELUM TERUNGKAP"
        KillerInfoLabel.TextColor3 = C.subtext
    end
end

createSection(HomeFrame, "KEYBIND DEFAULT", 157)
local keybinds = {
    { key = "R-CTRL", desc = "Sembunyikan / Tampilkan Menu" },
}
for i, kb in ipairs(keybinds) do
    local kCard = createCard(HomeFrame, 182 + (i-1) * 48, 40)
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
local updateESPUI = createToggle(VisualFrame, "👁", "ESP Player + Trap Butcher", 30, espEnabled, function(v)
    espEnabled = v
    saveConfig()
    if v then
        -- aktifkan trap scan sekalian
        scanTraps()
    else
        -- matikan highlight player
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local h = p.Character:FindFirstChild("ESPHighlight")
                if h then h.Enabled = false end
            end
        end
        -- matikan trap highlight
        for obj in pairs(trapHighlights) do
            removeTrapHighlight(obj)
        end
    end
end)

local updateAnimationArrowUI = createToggle(VisualFrame, "↗", "Arah Veil/Hidden", 78, arrowVeilEnabled, function(v)
    arrowVeilEnabled = v
    saveConfig()
end)

local scanPallets
local updateESPPalletUI = createToggle(VisualFrame, "🪵", "ESP Pallet", 126, espPallet, function(v)
    espPallet = v
    saveConfig()
    if v and scanPallets then scanPallets() end
    if not v then
        for obj in pairs(objectHighlights) do
            if obj and obj.Parent and (obj.Name == "Palletwrong" or obj.Name == "Pallet") then
                objectHighlights[obj]:Destroy()
                objectHighlights[obj] = nil
            end
        end
    end
end)

local updateESPGeneratorUI = createToggle(VisualFrame, "⚙", "ESP Generator + %", 174, espGenerator, function(v)
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

-- ========================
-- ESP TRAP (NEW)
-- ========================
local trapHighlights = {}

local TRAP_NAMES = {
    -- The Butcher / Violence District
    "Bear_Trap", "BearTrap", "Beartrap",
    "Trap", "trap",
    "Leghold", "LegholdTrap",
    "MacMillanTrap",
    -- nama umum lain yang sering dipakai game DBD-like
    "BloodwebTrap", "FloorTrap",
    "Punji", "PunjiStake",
    "CrowTrap", "SpringboardTrap",
}

local function isTrapObject(obj)
    if not (obj:IsA("Model") or obj:IsA("BasePart")) then return false end
    for _, name in ipairs(TRAP_NAMES) do
        if obj.Name == name then return true end
    end
    -- cek nama case-insensitive yang mengandung "trap"
    if obj.Name:lower():find("trap") then return true end
    return false
end

local function applyTrapHighlight(obj)
    if not obj or not obj.Parent then return end
    if trapHighlights[obj] and trapHighlights[obj].Parent then return end
    local highlight = Instance.new("Highlight")
    highlight.Name               = "HANGMA_TrapESP"
    highlight.Adornee            = obj
    highlight.FillColor          = C.orange
    highlight.OutlineColor       = C.orange
    highlight.FillTransparency   = 0.4
    highlight.OutlineTransparency = 0
    highlight.Parent             = obj
    trapHighlights[obj]          = highlight
end

local function removeTrapHighlight(obj)
    local h = trapHighlights[obj]
    if h then pcall(function() h:Destroy() end) end
    trapHighlights[obj] = nil
end

local function scanTraps()
    if not espEnabled then return end  -- ikut toggle ESP Player
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isTrapObject(obj) then
            applyTrapHighlight(obj)
        end
    end
end

-- Deteksi trap baru yang muncul (ikut espEnabled)
workspace.DescendantAdded:Connect(function(obj)
    if espEnabled and isTrapObject(obj) then
        task.wait(0.1)
        applyTrapHighlight(obj)
    end
end)

workspace.DescendantRemoving:Connect(function(obj)
    if trapHighlights[obj] then
        removeTrapHighlight(obj)
    end
end)

-- ESP Trap ikut espEnabled — scan saat init jika espEnabled sudah true
if espEnabled then scanTraps() end
-- ========================
-- END ESP TRAP
-- ========================

createSection(VisualFrame, "FOV", 281)
local updateFOVUI = createToggle(VisualFrame, "◎", "Pengubah FOV", 306, fovEnabled, function(v)
    fovEnabled = v
    if not v and not aimZoomActive then
        pcall(function() Camera.FieldOfView = defaultFOV end)
    end
    saveConfig()
end)
local fovInput = createLabelInput(VisualFrame, "👁", "Target FOV:", tostring(targetFOV), 354, function(txt) targetFOV = tonumber(txt) or 100; saveConfig() end)

createSection(VisualFrame, "CROSSHAIR", 409)
local updateCrosshairUI = createToggle(VisualFrame, "⌖", "Custom Crosshair", 434, crosshairEnabled, function(v) crosshairEnabled = v; saveConfig() end)

createSection(VisualFrame, "LIGHTING", 481)
local updateFullBrightUI = createToggle(VisualFrame, "☼", "Full Bright", 506, fullBrightEnabled, function(v)
    fullBrightEnabled = v
    applyFullBright(v)
    if v then lastFullBrightApply = tick() end
    saveConfig()
end)

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
-- ========================
local espConnections = {}

local ARROW_ANIMATION_IDS = {
    ["77307334522729"] = true,
    ["87436543050891"] = true,
    ["79809716042968"] = true,
    ["122765810542358"] = true,
    ["101443662521580"] = true,
    ["84404617997921"] = true,
    ["88848807662765"] = true,
    ["123809268724645"] = true,
}

local ARROW_LINE_LINGER = 2.5
local ARROW_LINE_LENGTH = 60
local ANIMATION_ARROW_FOLDER_NAME = "VD_AnimationArrowESP_Local"
local animationArrowFolder = workspace:FindFirstChild(ANIMATION_ARROW_FOLDER_NAME)
if animationArrowFolder then
    pcall(function() animationArrowFolder:Destroy() end)
end
animationArrowFolder = Instance.new("Folder")
animationArrowFolder.Name = ANIMATION_ARROW_FOLDER_NAME
animationArrowFolder.Parent = workspace

local animationArrowLines = {}
local animationArrowStates = {}

local function clearAnimationArrowLine(player)
    local line = animationArrowLines[player]
    if not line then return end
    animationArrowLines[player] = nil
    pcall(function() line.beam:Destroy() end)
    pcall(function() line.origin:Destroy() end)
    pcall(function() line.endpointPart:Destroy() end)
end

local function clearAllAnimationArrowLines()
    for player in pairs(animationArrowLines) do
        clearAnimationArrowLine(player)
    end
    animationArrowStates = {}
end

local function destroyAnimationArrowFolder()
    clearAllAnimationArrowLines()
    if animationArrowFolder then
        pcall(function() animationArrowFolder:Destroy() end)
        animationArrowFolder = nil
    end
end

local function getArrowSourcePosition(character, root)
    local spearModel = character and character:FindFirstChild("Spear", true)
    local handle = spearModel and spearModel:FindFirstChild("SpearHandle", true)
    if handle and handle:IsA("BasePart") then return handle.Position end
    if character then
        for _, object in ipairs(character:GetDescendants()) do
            if object:IsA("BasePart") and string.lower(object.Name) == "spearhandle" then
                return object.Position
            end
        end
    end
    return root.Position + Vector3.new(0, 1.2, 0)
end

local function setAnimationArrowLine(player, root, direction, color)
    local line = animationArrowLines[player]
    if line and (not line.source.Parent or line.source ~= root) then
        clearAnimationArrowLine(player)
        line = nil
    end
    if not line then
        local origin = Instance.new("Attachment")
        origin.Name = "VD_AnimationArrowOrigin"
        origin.Position = root.CFrame:PointToObjectSpace(getArrowSourcePosition(root.Parent, root))
        origin.Parent = root

        local endpointPart = Instance.new("Part")
        endpointPart.Name = "VD_AnimationArrowEndpoint"
        endpointPart.Anchored = true
        endpointPart.CanCollide = false
        endpointPart.CanTouch = false
        endpointPart.CanQuery = false
        endpointPart.Transparency = 1
        endpointPart.Size = Vector3.new(0.1, 0.1, 0.1)
        endpointPart.CFrame = CFrame.new(root.Position)
        endpointPart.Parent = animationArrowFolder

        local endpoint = Instance.new("Attachment")
        endpoint.Name = "VD_AnimationArrowEnd"
        endpoint.Parent = endpointPart

        local beam = Instance.new("Beam")
        beam.Name = "VD_AnimationArrowLine"
        beam.Attachment0 = origin
        beam.Attachment1 = endpoint
        beam.FaceCamera = true
        beam.Width0 = 0.12
        beam.Width1 = 0.08
        beam.LightEmission = 0.7
        beam.LightInfluence = 0
        beam.Color = ColorSequence.new(color or Color3.fromRGB(255, 255, 255))
        beam.Transparency = NumberSequence.new(0.08)
        beam.Enabled = false
        beam.Parent = animationArrowFolder
        line = { source = root, origin = origin, endpointPart = endpointPart, beam = beam }
        animationArrowLines[player] = line
    end

    local startPosition = getArrowSourcePosition(root.Parent, root)
    line.origin.Position = root.CFrame:PointToObjectSpace(startPosition)
    line.endpointPart.CFrame = CFrame.new(startPosition + direction * ARROW_LINE_LENGTH)
    line.beam.Color = ColorSequence.new(color or Color3.fromRGB(255, 255, 255))
    line.beam.Enabled = true
end

local function isArrowAnimationPlaying(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not animator then return false end

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        if track.IsPlaying and track.WeightCurrent > 0.05 then
            local animation = track.Animation
            local animationId = animation and string.match(tostring(animation.AnimationId), "%d+")
            if animationId and ARROW_ANIMATION_IDS[animationId] then
                return true
            end
        end
    end
    return false
end

local SPEAR_PART_NAME_HINTS = { "spear", "trident", "lance", "javelin", "fork", "weapon", "hiddenweapon", "veilweapon" }
local RIG_BODY_PART_NAMES = {
    ["humanoidrootpart"] = true, ["head"] = true, ["torso"] = true,
    ["uppertorso"] = true, ["lowertorso"] = true,
    ["left arm"] = true, ["right arm"] = true, ["left leg"] = true, ["right leg"] = true,
    ["leftupperarm"] = true, ["rightupperarm"] = true,
    ["leftlowerarm"] = true, ["rightlowerarm"] = true,
    ["lefthand"] = true, ["righthand"] = true,
    ["leftupperleg"] = true, ["rightupperleg"] = true,
    ["leftlowerleg"] = true, ["rightlowerleg"] = true,
    ["leftfoot"] = true, ["rightfoot"] = true,
}
local spearPartsCache = setmetatable({}, { __mode = "k" })

local function partHasSpearAncestor(part, character)
    local node = part
    while node and node ~= character do
        local name = string.lower(node.Name)
        for _, hint in ipairs(SPEAR_PART_NAME_HINTS) do
            if string.find(name, hint, 1, true) then return true end
        end
        node = node.Parent
    end
    return false
end

local function partHasToolAncestor(part, character)
    local node = part
    while node and node ~= character do
        if node:IsA("Tool") then return true end
        node = node.Parent
    end
    return false
end

local function isLongThinPartNearHand(part, character)
    local dimensions = { part.Size.X, part.Size.Y, part.Size.Z }
    table.sort(dimensions)
    if dimensions[3] < 3.2 or dimensions[3] / math.max(dimensions[1], 0.1) < 3 then
        return false
    end
    local hand = character:FindFirstChild("RightHand")
        or character:FindFirstChild("Right Arm")
        or character:FindFirstChild("RightLowerArm")
    return hand and (part.Position - hand.Position).Magnitude <= 8 or false
end

local function findSpearParts(character)
    local now = tick()
    local cached = spearPartsCache[character]
    if cached and now < cached.expiresAt then
        return cached.parts
    end

    local parts = {}
    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BasePart") and not RIG_BODY_PART_NAMES[string.lower(obj.Name)] then
            if partHasSpearAncestor(obj, character)
                or partHasToolAncestor(obj, character)
                or isLongThinPartNearHand(obj, character) then
                table.insert(parts, obj)
            end
        end
    end
    spearPartsCache[character] = { parts = parts, expiresAt = now + 0.5 }
    return parts
end

local function getLongAxis(part)
    local size = part.Size
    local dimensions = { size.X, size.Y, size.Z }
    table.sort(dimensions)
    if dimensions[3] / math.max(dimensions[1], 0.1) < 1.25 then
        return part.CFrame.LookVector
    end
    if size.X >= size.Y and size.X >= size.Z then
        return part.CFrame.RightVector
    elseif size.Y >= size.X and size.Y >= size.Z then
        return part.CFrame.UpVector
    end
    return part.CFrame.LookVector
end

local function orientWeaponVector(direction, character, root)
    if direction.Magnitude < 0.01 then return nil end
    direction = direction.Unit
    local reference = root.CFrame.LookVector
    if math.abs(direction:Dot(reference)) < 0.08 then
        local head = character:FindFirstChild("Head") or character:FindFirstChild("UpperTorso")
        if head then reference = head.CFrame.LookVector end
    end
    if direction:Dot(reference) < 0 then direction = -direction end
    return direction
end

local function getSpearHandleDirection(handle, character, root)
    local size = handle.Size
    local axis, halfLength
    if size.X >= size.Y and size.X >= size.Z then
        axis, halfLength = handle.CFrame.RightVector, size.X * 0.5
    elseif size.Y >= size.X and size.Y >= size.Z then
        axis, halfLength = handle.CFrame.UpVector, size.Y * 0.5
    else
        axis, halfLength = handle.CFrame.LookVector, size.Z * 0.5
    end

    local hand = character:FindFirstChild("RightHand")
        or character:FindFirstChild("Right Arm")
        or character:FindFirstChild("RightLowerArm")
    if hand then
        local positiveEnd = handle.Position + axis * halfLength
        local negativeEnd = handle.Position - axis * halfLength
        local positiveDistance = (positiveEnd - hand.Position).Magnitude
        local negativeDistance = (negativeEnd - hand.Position).Magnitude
        if math.abs(positiveDistance - negativeDistance) > 0.1 then
            -- On this rig, the visible spearhead is on the endpoint nearer the gripping hand.
            local tipEnd = positiveDistance < negativeDistance and positiveEnd or negativeEnd
            local direction = tipEnd - handle.Position
            if direction.Magnitude > 0.01 then return direction.Unit end
        end
    end
    return orientWeaponVector(axis, character, root)
end

local function getSpearDirection(character, root)
    -- The beam starts at SpearHandle; its aim follows the killer's head in 3D.
    local head = character:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        local direction = head.CFrame.LookVector
        if direction.Magnitude > 0.01 then return direction.Unit end
    end

    local upperTorso = character:FindFirstChild("UpperTorso")
    if upperTorso and upperTorso:IsA("BasePart") then
        return upperTorso.CFrame.LookVector.Unit
    end
    return root.CFrame.LookVector.Unit
end


local function getAnimationArrowLineColor(shooter, root, direction)
    local origin = getArrowSourcePosition(shooter.Character, root)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { shooter.Character, animationArrowFolder }
    params.IgnoreWater = true

    local result = workspace:Raycast(origin, direction * ARROW_LINE_LENGTH, params)
    if result then
        for _, targetPlayer in ipairs(Players:GetPlayers()) do
            local targetCharacter = targetPlayer.Character
            if targetPlayer ~= shooter and targetCharacter
                and result.Instance:IsDescendantOf(targetCharacter) then
                return Color3.fromRGB(255, 60, 80)
            end
        end
    end
    return Color3.fromRGB(255, 255, 255)
end

local function updateAnimationArrowESP()
    if not arrowVeilEnabled then
        clearAllAnimationArrowLines()
        return
    end

    local now = tick()
    local seen = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isKiller(player) then
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if root and root:IsA("BasePart") then
                seen[player] = true
                local state = animationArrowStates[player] or {}
                if isArrowAnimationPlaying(character) then
                    local direction = getSpearDirection(character, root)
                    if direction and direction.Magnitude > 0.01 then
                        state.direction = direction.Unit
                    end
                    state.lastActive = now
                    animationArrowStates[player] = state
                end

                if state.lastActive and now - state.lastActive <= ARROW_LINE_LINGER and state.direction then
                    local lineColor = getAnimationArrowLineColor(player, root, state.direction)
                    setAnimationArrowLine(player, root, state.direction, lineColor)
                else
                    clearAnimationArrowLine(player)
                    animationArrowStates[player] = nil
                end
            end
        end
    end

    for player in pairs(animationArrowLines) do
        if not seen[player] then clearAnimationArrowLine(player) end
    end
    for player in pairs(animationArrowStates) do
        if not seen[player] then animationArrowStates[player] = nil end
    end
end


local function cleanESPHighlight(character)
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
    if espConnections[player] then
        espConnections[player]:Disconnect()
        espConnections[player] = nil
    end
    if player.Character then
        applyESP(player)
    end
    espConnections[player] = player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
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

for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        setupPlayerESP(p)
    end
end

Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then
        setupPlayerESP(p)
    end
end)

Players.PlayerRemoving:Connect(function(p)
    espConnections[p] = nil
    clearAnimationArrowLine(p)
    animationArrowStates[p] = nil
end)

-- ========================
-- OBJECT ESP: PALLET + GENERATOR
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

local function isPalletObject(obj)
    return (obj:IsA("Model") or obj:IsA("BasePart"))
        and (obj.Name == "Palletwrong" or obj.Name == "Pallet")
end

scanPallets = function()
    if not espPallet then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isPalletObject(obj) then
            applyObjectHighlight(obj, Color3.fromRGB(74, 255, 181))
        end
    end
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

workspace.DescendantAdded:Connect(function(obj)
    if espPallet and isPalletObject(obj) then
        applyObjectHighlight(obj, Color3.fromRGB(74, 255, 181))
    end
end)

workspace.DescendantRemoving:Connect(function(obj)
    if objectHighlights[obj] or generatorBillboards[obj] then
        removeObjectESP(obj)
    end
end)

if espPallet then scanPallets() end

local function updateObjectESP()
    local now = tick()
    if now - lastObjectESPUpdate < 0.25 then return end
    lastObjectESPUpdate = now
    local map = workspace:FindFirstChild("Map")
    local seenGenerators = {}

    if espGenerator and map then
        for _, obj in ipairs(map:GetDescendants()) do
            if obj:IsA("Model") and obj.Name == "Generator" then
                seenGenerators[obj] = true
                local percent = getGeneratorPercent(obj)
                if percent and percent >= 100 then
                    removeObjectESP(obj)
                else
                    applyObjectHighlight(obj, Color3.fromRGB(180, 100, 255))
                    updateGeneratorBillboard(obj, percent)
                end
            end
        end
    end

    for obj in pairs(objectHighlights) do
        if obj.Name == "Generator" then
            if not (espGenerator and seenGenerators[obj]) then
                removeObjectESP(obj)
            end
        elseif isPalletObject(obj) then
            if not (espPallet and obj.Parent) then
                removeObjectESP(obj)
            end
        else
            removeObjectESP(obj)
        end
    end
    for obj in pairs(generatorBillboards) do
        if not seenGenerators[obj] then removeObjectESP(obj) end
    end
end

local function resetConfig()
    espEnabled = false
    arrowVeilEnabled = false
    clearAllAnimationArrowLines()
    espPallet = false
    espGenerator = false
    if not aimZoomActive then
        pcall(function() Camera.FieldOfView = defaultFOV end)
    end
    crosshairEnabled = false
    fovEnabled = false
    fullBrightEnabled = false
    skillcheckEnabled = false
    skillcheckNotPerfectEnabled = false
    targetFOV = 100
    applyFullBright(false)

    updateESPUI(false)
    updateAnimationArrowUI(false)
    updateESPPalletUI(false)
    updateESPGeneratorUI(false)
    updateFOVUI(false)
    updateCrosshairUI(false)
    updateFullBrightUI(false)
    updateSkillcheckUI(false)
    updateSkillcheckNotPerfectUI(false)
    fovInput.Text = "100"

    for obj, highlight in pairs(objectHighlights) do
        pcall(function() highlight:Destroy() end)
        objectHighlights[obj] = nil
    end
    for obj, billboard in pairs(generatorBillboards) do
        pcall(function() billboard:Destroy() end)
        generatorBillboards[obj] = nil
    end
    -- clear trap highlights
    for obj in pairs(trapHighlights) do
        removeTrapHighlight(obj)
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
    pcall(doSkillcheck)

    -- Leave short-term camera zooms (such as Twist of Fate aim zoom) to the game.
    local currentFOV = Camera and Camera.FieldOfView
    if currentFOV then
        local normalFOV = fovEnabled and math.min(defaultFOV, targetFOV) or defaultFOV
        local gameOwnsFOV = false
        if aimZoomActive then
            if currentFOV >= normalFOV - 1 then
                aimZoomActive = false
            else
                gameOwnsFOV = true
            end
        end

        if not gameOwnsFOV then
            if currentFOV < normalFOV - 2 then
                aimZoomActive = true
            elseif fovEnabled then
                if math.abs(currentFOV - targetFOV) > 0.05 then
                    Camera.FieldOfView = targetFOV
                end
            else
                -- Follow the game's normal camera FOV while the custom changer is off.
                defaultFOV = currentFOV
            end
        end
    end

    local now = tick()
    if fullBrightEnabled and now - lastFullBrightApply >= 0.5 then
        lastFullBrightApply = now
        applyFullBright(true)
    end

    CrosshairGUI.Visible = crosshairEnabled

    pcall(updateObjectESP)
    pcall(updateAnimationArrowESP)

    if espEnabled then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local h = p.Character:FindFirstChild("ESPHighlight")
                if h then
                    h.Enabled      = true
                    h.FillColor    = isKiller(p) and C.red or C.green
                    h.OutlineColor = isKiller(p) and C.red or C.green
                elseif espEnabled then
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

updateKillerInfo()
showTab("HOME")
saveConfig()
