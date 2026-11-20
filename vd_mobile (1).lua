--[[
    By cuqy puky
    Mobile + Delta Compatible
    FIX: Circle drag vs tap separation
    NEW: Auto Save/Load Config + ESP per kategori + ESP Trap (auto with Player)
]]

-- double-init guard
if _G.HANGMA_LOADED then
    warn("[HANGMA] Already loaded. Unload first.")
    return
end
_G.HANGMA_LOADED = true

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
local GuiService          = game:GetService("GuiService")
local Lighting            = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ========================
-- PLATFORM DETECT
-- ========================
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ========================
-- SAVE/LOAD CONFIG
-- ========================
local CONFIG_KEY = "HANGMA_V10_CONFIG"

local defaultConfig = {
    espPlayer               = false,
    espPallet               = false,
    espWindow               = false,
    espHook                 = false,
    espGenerator            = false,
    espGate                 = false,
    crosshairEnabled        = false,
    fovEnabled              = false,
    fullBrightEnabled       = false,
    skillcheckEnabled           = false,
    skillcheckNotPerfectEnabled = false,
    targetFOV               = 100,
}

local function saveConfig(cfg)
    pcall(function()
        writefile(CONFIG_KEY .. ".json", HttpService:JSONEncode(cfg))
    end)
end

local function loadConfig()
    local ok, result = pcall(function()
        if isfile(CONFIG_KEY .. ".json") then
            return HttpService:JSONDecode(readfile(CONFIG_KEY .. ".json"))
        end
    end)
    if ok and type(result) == "table" then
        for k, v in pairs(defaultConfig) do
            if result[k] == nil then result[k] = v end
        end
        return result
    end
    return defaultConfig
end

local cfg = loadConfig()

-- ========================
-- STATE
-- ========================
local espPlayer               = cfg.espPlayer
local espPallet               = cfg.espPallet
local espWindow               = cfg.espWindow
local espHook                 = cfg.espHook
local espGenerator            = cfg.espGenerator
local espGate                 = cfg.espGate
local crosshairEnabled        = cfg.crosshairEnabled
local fovEnabled              = cfg.fovEnabled
local skillcheckEnabled           = cfg.skillcheckEnabled
local skillcheckNotPerfectEnabled = cfg.skillcheckNotPerfectEnabled
local fullBrightEnabled           = cfg.fullBrightEnabled == true

-- Snapshot only the Lighting properties this feature changes. This lets the
-- toggle and unload path restore the values that were present when the script started.
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
        local value = enabled and brightValue or originalLighting[property]
        -- Lua's `and/or` idiom cannot represent false, so preserve GlobalShadows=false explicitly.
        if enabled and property == "GlobalShadows" then value = false end
        if value ~= nil then
            pcall(function() Lighting[property] = value end)
        end
    end
end

if fullBrightEnabled then
    applyFullBright(true)
end

local isMouseDown      = false
local isRightMouseDown = false
local hideMenuKey      = Enum.KeyCode.RightControl
local targetFOV        = cfg.targetFOV or 100
local defaultFOV       = Camera.FieldOfView
local aimZoomActive    = false

local function saveAll()
    saveConfig({
        espPlayer               = espPlayer,
        espPallet               = espPallet,
        espWindow               = espWindow,
        espHook                 = espHook,
        espGenerator            = espGenerator,
        espGate                 = espGate,
        crosshairEnabled        = crosshairEnabled,
        fovEnabled              = fovEnabled,
        fullBrightEnabled       = fullBrightEnabled,
        skillcheckEnabled           = skillcheckEnabled,
        skillcheckNotPerfectEnabled = skillcheckNotPerfectEnabled,
        targetFOV               = targetFOV,
    })
end

local TouchID              = 8822
local ActionPath           = "Survivor-mob.Controls.action.check"
local HeartbeatConnection  = nil
local VisibilityConnection = nil
local PlayerGui            = LocalPlayer:WaitForChild("PlayerGui")

-- ========================
-- UNLOAD GUARD
-- ========================
local ScriptRunning        = true
local _RenderConnection    = nil
local _MainHBConnection    = nil
local _AllConnections      = {}

local function _trackConn(c)
    if c then table.insert(_AllConnections, c) end
    return c
end

-- ESP state
local IndicatorGui      = nil
local ActiveGenerators  = {}
local LastUpdateTick    = 0
local LastESPRefresh    = 0
local LastFullBrightApply = 0

-- Trap ESP state
local trapHighlights    = {}

local function _doUnload()
    ScriptRunning = false
    applyFullBright(false)
    pcall(function()
        if Camera and not aimZoomActive then Camera.FieldOfView = defaultFOV end
    end)
    if HeartbeatConnection  then HeartbeatConnection:Disconnect();  HeartbeatConnection  = nil end
    if VisibilityConnection then VisibilityConnection:Disconnect(); VisibilityConnection = nil end
    if _RenderConnection    then _RenderConnection:Disconnect();    _RenderConnection    = nil end
    if _MainHBConnection    then _MainHBConnection:Disconnect();    _MainHBConnection    = nil end
    for _, c in ipairs(_AllConnections) do
        pcall(function() if c.Connected then c:Disconnect() end end)
    end
    _AllConnections = {}
    for obj, h in pairs(trapHighlights) do
        pcall(function() h:Destroy() end)
        trapHighlights[obj] = nil
    end
    if IndicatorGui and IndicatorGui.Parent then IndicatorGui:Destroy() end
    if ScreenGui    and ScreenGui.Parent    then ScreenGui:Destroy()    end
    _G.HANGMA_LOADED = nil
    print("[HANGMA] Unloaded.")
end

-- ========================
-- UTILS
-- ========================
local function isKillerTeam(player)
    local t = player.Team and player.Team.Name:lower() or ""
    return t:find("killer") ~= nil
end

local function isOverFrame(frame)
    if not frame.Visible then return false end
    local mouse = UserInputService:GetMouseLocation()
    local pos   = frame.AbsolutePosition
    local size  = frame.AbsoluteSize
    return mouse.X >= pos.X and mouse.X <= pos.X + size.X
       and mouse.Y >= pos.Y and mouse.Y <= pos.Y + size.Y
end

local function GetGameValue(obj, name)
    if not obj then return nil end
    local attr = obj:GetAttribute(name)
    if attr ~= nil then return attr end
    local child = obj:FindFirstChild(name)
    if child then
        local ok, val = pcall(function() return child.Value end)
        if ok then return val end
    end
    return nil
end

local ESPColors = {
    Killer    = Color3.fromRGB(255, 93,  108),
    Survivor  = Color3.fromRGB(64,  224, 255),
    Hooked    = Color3.fromRGB(255, 182, 193),
    Knocked   = Color3.fromRGB(200, 100, 0),
    Injured   = Color3.fromRGB(200, 200, 0),
    Generator = Color3.fromRGB(150, 0,   200),
    Gate      = Color3.fromRGB(255, 255, 255),
    Pallet    = Color3.fromRGB(74,  255, 181),
    Window    = Color3.fromRGB(74,  255, 181),
    Hook      = Color3.fromRGB(132, 255, 169),
    Trap      = Color3.fromRGB(255, 160, 40),   -- orange, sama dengan vdpc
}

local MaskNames = {
    ["Richard"] = "Rooster", ["Tony"]   = "Tiger",
    ["Brandon"] = "Panther", ["Cobra"]  = "Cobra",
    ["Richter"] = "Rat",     ["Rabbit"] = "Rabbit",
    ["Alex"]    = "Chainsaw",
}
local MaskColors = {
    ["Richard"] = Color3.fromRGB(255, 0,   0),
    ["Tony"]    = Color3.fromRGB(255, 255, 0),
    ["Brandon"] = Color3.fromRGB(160, 32,  240),
    ["Cobra"]   = Color3.fromRGB(0,   255, 0),
    ["Richter"] = Color3.fromRGB(0,   0,   0),
    ["Rabbit"]  = Color3.fromRGB(255, 105, 180),
    ["Alex"]    = Color3.fromRGB(255, 255, 255),
}

-- ========================
-- TRAP DETECTION (dari vdpc)
-- ========================
local TRAP_NAMES = {
    "Bear_Trap", "BearTrap", "Beartrap",
    "Trap", "trap",
    "Leghold", "LegholdTrap",
    "MacMillanTrap",
    "BloodwebTrap", "FloorTrap",
    "Punji", "PunjiStake",
    "CrowTrap", "SpringboardTrap",
}

local function isTrapObject(obj)
    if not (obj:IsA("Model") or obj:IsA("BasePart")) then return false end
    for _, name in ipairs(TRAP_NAMES) do
        if obj.Name == name then return true end
    end
    if obj.Name:lower():find("trap") then return true end
    return false
end

local function applyTrapHighlight(obj)
    if not obj or not obj.Parent then return end
    if trapHighlights[obj] and trapHighlights[obj].Parent then return end
    local highlight = Instance.new("Highlight")
    highlight.Name                = "HANGMA_TrapESP"
    highlight.Adornee             = obj
    highlight.FillColor           = ESPColors.Trap
    highlight.OutlineColor        = ESPColors.Trap
    highlight.FillTransparency    = 0.4
    highlight.OutlineTransparency = 0
    highlight.Enabled             = espPlayer
    highlight.Parent              = obj
    trapHighlights[obj]           = highlight
end

local function removeTrapHighlight(obj)
    local h = trapHighlights[obj]
    if h then pcall(function() h:Destroy() end) end
    trapHighlights[obj] = nil
end

local function scanTraps()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isTrapObject(obj) then
            applyTrapHighlight(obj)
        end
    end
end

local function setAllTrapEnabled(state)
    for _, h in pairs(trapHighlights) do
        if h and h.Parent then h.Enabled = state end
    end
end

-- auto-detect trap baru muncul
workspace.DescendantAdded:Connect(function(obj)
    if espPlayer and isTrapObject(obj) then
        task.wait(0.1)
        applyTrapHighlight(obj)
    end
end)

workspace.DescendantRemoving:Connect(function(obj)
    if trapHighlights[obj] then
        removeTrapHighlight(obj)
    end
end)

-- ========================
-- GUI SETUP
-- ========================
if CoreGui:FindFirstChild("CUKY_PUQY_GUI") then
    CoreGui:FindFirstChild("CUKY_PUQY_GUI"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "CUKY_PUQY_GUI"
ScreenGui.Parent         = CoreGui
ScreenGui.ResetOnSpawn   = false
ScreenGui.DisplayOrder   = 999
ScreenGui.IgnoreGuiInset = true

-- External image URLs are resolved to executor custom assets when supported.
-- If the executor blocks downloads, the text fallback remains visible and the UI still works.
local MENU_LOGO_URL = "https://i.ibb.co.com/HDxwfDRR/photo-2026-11-20-21-51-15.jpg"
local MINIMIZED_LOGO_URL = "https://i.ibb.co.com/PZyLNGKh/photo-2026-11-20-21-51-11.jpg"
local function resolveCustomImage(url, filename)
    local getAsset = getcustomasset or getsynasset
    local requestFn = request or http_request or (syn and syn.request)
    if type(getAsset) ~= "function" or type(requestFn) ~= "function" or type(writefile) ~= "function" then
        return nil
    end
    local path = "CUKY_PUQY_" .. filename .. ".jpg"
    local okFile = pcall(function() return isfile(path) end)
    if not okFile or not isfile(path) then
        local okReq, response = pcall(function()
            return requestFn({Url = url, Method = "GET"})
        end)
        if okReq and response and response.Body then
            pcall(function() writefile(path, response.Body) end)
        end
    end
    local okAsset, asset = pcall(function() return getAsset(path) end)
    return okAsset and asset or nil
end

local C = {
    -- Palet charcoal dengan aksen abu-biru yang lebih redup.
    bg        = Color3.fromRGB(8,   9,   12),
    panel     = Color3.fromRGB(14,  16,  20),
    card      = Color3.fromRGB(23,  26,  32),
    border    = Color3.fromRGB(58,  68,  78),
    accent    = Color3.fromRGB(112, 184, 172),
    accentDim = Color3.fromRGB(31,  51,  54),
    red       = Color3.fromRGB(205, 112, 120),
    green     = Color3.fromRGB(143, 190, 154),
    text      = Color3.fromRGB(232, 235, 240),
    subtext   = Color3.fromRGB(145, 152, 164),
    off       = Color3.fromRGB(48,  53,  63),
    white     = Color3.fromRGB(235, 238, 243),
    orange    = Color3.fromRGB(198, 157, 105),
    on        = Color3.fromRGB(58,  145, 118),
}

local FONT_BRAND = Enum.Font.GothamBold
local FONT_HEAD  = Enum.Font.GothamMedium
local FONT_BODY  = Enum.Font.Gotham

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

local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(390, 800)
local FRAME_W = isMobile and math.min(430, math.max(320, viewport.X - 24)) or 520
local FRAME_H = isMobile and math.min(360, math.max(280, math.floor(viewport.Y * 0.45))) or 360
local SIDE_W  = isMobile and 112 or 136

local TOGGLE_H  = isMobile and 58 or 52
local TOGGLE_W  = isMobile and 50 or 54
local TOGGLE_SH = 23
local TOGGLE_CR = 12
local CIRCLE_SZ = isMobile and 18 or 18
local CIRCLE_CR = 9
local ICON_SZ   = isMobile and 16 or 15
local LABEL_SZ  = isMobile and 12 or 12

-- ========================
-- MAIN FRAME
-- ========================
local MainFrame = Instance.new("Frame")
MainFrame.Name              = "MainFrame"
MainFrame.Parent            = ScreenGui
MainFrame.BackgroundColor3  = C.bg
MainFrame.BorderSizePixel   = 0
MainFrame.Position          = UDim2.new(0.5, -FRAME_W/2, 0.5, -FRAME_H/2)
MainFrame.Size              = UDim2.new(0, FRAME_W, 0, FRAME_H)
MainFrame.Active            = true
MainFrame.Draggable         = not isMobile
MainFrame.ClipsDescendants  = true
addCorner(MainFrame, 12)
local mainStroke = addStroke(MainFrame, C.border, 1.25)
mainStroke.Transparency = 0.18
addGradient(MainFrame, Color3.fromRGB(20, 23, 29), Color3.fromRGB(8, 9, 12), 90)

-- ========================
-- SIDEBAR
-- ========================
local Sidebar = Instance.new("Frame")
Sidebar.Name             = "Sidebar"
Sidebar.Parent           = MainFrame
Sidebar.BackgroundColor3 = C.panel
Sidebar.BorderSizePixel  = 0
Sidebar.Size             = UDim2.new(0, SIDE_W, 1, 0)
local sidebarStroke = addStroke(Sidebar, C.border, 1)
sidebarStroke.Transparency = 0.35

local Logo = Instance.new("TextLabel")
Logo.Parent                 = Sidebar
Logo.BackgroundTransparency = 1
Logo.Position               = UDim2.new(0, 4, 0, 59)
Logo.Size                   = UDim2.new(1, -8, 0, 22)
Logo.Font                   = FONT_BRAND
Logo.Text                   = "CUKY PUQY"
Logo.TextColor3             = C.accent
Logo.TextSize               = isMobile and 12 or 18
Logo.TextXAlignment         = Enum.TextXAlignment.Center

local MenuLogo = Instance.new("ImageLabel")
MenuLogo.Name = "MenuLogo"
MenuLogo.Parent = Sidebar
MenuLogo.BackgroundColor3 = C.card
MenuLogo.BorderSizePixel = 0
MenuLogo.ImageColor3 = C.white
MenuLogo.Position = UDim2.new(0.5, -24, 0, 8)
MenuLogo.Size = UDim2.new(0, 48, 0, 48)
MenuLogo.ScaleType = Enum.ScaleType.Crop
MenuLogo.ZIndex = 3
addCorner(MenuLogo, 24)
local menuAsset = resolveCustomImage(MENU_LOGO_URL, "menu_v2")
if menuAsset then
    MenuLogo.Image = menuAsset
end

local TabContainer = Instance.new("Frame")
TabContainer.Parent                 = Sidebar
TabContainer.BackgroundTransparency = 1
local SearchBox = Instance.new("TextBox")
SearchBox.Name = "SearchFeature"
SearchBox.Parent = Sidebar
SearchBox.BackgroundColor3 = C.card
SearchBox.BorderSizePixel = 0
SearchBox.Position = UDim2.new(0, 9, 0, 91)
SearchBox.Size = UDim2.new(1, -18, 0, 30)
SearchBox.Font = Enum.Font.Gotham
SearchBox.Text = ""
SearchBox.PlaceholderText = "Search feature..."
SearchBox.PlaceholderColor3 = C.subtext
SearchBox.TextColor3 = C.white
SearchBox.TextSize = 9
SearchBox.ClearTextOnFocus = false
SearchBox.ZIndex = 4
addCorner(SearchBox, 5)
local searchStroke = addStroke(SearchBox, C.border, 1); searchStroke.Transparency = 0.45

local SidebarDivider = Instance.new("Frame")
SidebarDivider.Name = "SidebarDivider"
SidebarDivider.Parent = Sidebar
SidebarDivider.BackgroundColor3 = C.border
SidebarDivider.BorderSizePixel = 0
SidebarDivider.Position = UDim2.new(0, 10, 0, 82)
SidebarDivider.Size = UDim2.new(1, -20, 0, 1)

TabContainer.Position               = UDim2.new(0, 9, 0, 128)
TabContainer.Size                   = UDim2.new(1, -18, 1, -136)
local TabListLayout = Instance.new("UIListLayout")
TabListLayout.Parent  = TabContainer
TabListLayout.Padding = UDim.new(0, 8)

-- ========================
-- CONTENT AREA
-- ========================
local ContentArea = Instance.new("Frame")
ContentArea.Name                   = "ContentArea"
ContentArea.Parent                 = MainFrame
ContentArea.BackgroundTransparency = 1
ContentArea.Position               = UDim2.new(0, SIDE_W, 0, 34)
ContentArea.Size                   = UDim2.new(1, -SIDE_W, 1, -34)

local WindowTitle = Instance.new("TextLabel")
WindowTitle.Name = "WindowTitle"
WindowTitle.Parent = MainFrame
WindowTitle.BackgroundTransparency = 1
WindowTitle.Position = UDim2.new(0, SIDE_W + 12, 0, 5)
WindowTitle.Size = UDim2.new(1, -(SIDE_W + 66), 0, 22)
WindowTitle.Font = FONT_HEAD
WindowTitle.Text = "CUKY PUQY"
WindowTitle.TextColor3 = C.white
WindowTitle.TextSize = isMobile and 13 or 14
WindowTitle.TextXAlignment = Enum.TextXAlignment.Left
local WindowLine = Instance.new("Frame")
WindowLine.Parent = MainFrame
WindowLine.BackgroundColor3 = C.border
WindowLine.BorderSizePixel = 0
WindowLine.Position = UDim2.new(0, SIDE_W + 12, 0, 31)
WindowLine.Size = UDim2.new(1, -(SIDE_W + 24), 0, 1)

-- ========================
-- doMinimize
-- ========================
local minimized = false
local fullSize  = UDim2.new(0, FRAME_W, 0, FRAME_H)
local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CircleBtn

local function doMinimize()
    minimized = not minimized
    if minimized then
        local mpos = MainFrame.Position
        TweenService:Create(MainFrame, tweenInfo, { Size = UDim2.new(0, FRAME_W, 0, 0) }):Play()
        task.delay(0.2, function()
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

-- ========================
-- CIRCLE BTN
-- ========================
CircleBtn = Instance.new("TextButton")
CircleBtn.Name             = "CircleBtn"
CircleBtn.Parent           = ScreenGui
CircleBtn.BackgroundColor3 = C.bg
CircleBtn.Position         = UDim2.new(0, 12, 0, 12)
CircleBtn.Size             = UDim2.new(0, isMobile and 60 or 50, 0, isMobile and 60 or 50)
CircleBtn.Font             = FONT_BRAND
CircleBtn.Text             = "C"
CircleBtn.TextColor3       = C.white
CircleBtn.TextSize         = isMobile and 24 or 20
CircleBtn.ZIndex           = 20
CircleBtn.AutoButtonColor  = false
CircleBtn.Visible          = false
addCorner(CircleBtn, isMobile and 30 or 25)
addStroke(CircleBtn, C.white, 2)
local MinimizedLogo = Instance.new("ImageLabel")
MinimizedLogo.Name = "ChromeHeartLogo"
MinimizedLogo.Parent = CircleBtn
MinimizedLogo.BackgroundTransparency = 1
MinimizedLogo.Size = UDim2.new(1, -8, 1, -8)
MinimizedLogo.Position = UDim2.new(0, 4, 0, 4)
MinimizedLogo.ScaleType = Enum.ScaleType.Crop
MinimizedLogo.ZIndex = 21
local minimizedAsset = resolveCustomImage(MINIMIZED_LOGO_URL, "minimized")
if minimizedAsset then
    MinimizedLogo.Image = minimizedAsset
    CircleBtn.Text = ""
    addCorner(MinimizedLogo, isMobile and 26 or 21)
end

do
    local drag, dstart, dpos, didMove = false, nil, nil, false
    local THRESHOLD = 10
    CircleBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true; didMove = false
            dstart = input.Position; dpos = CircleBtn.Position
        end
    end)
    CircleBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = false
            if not didMove then doMinimize() end
            didMove = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if drag and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            if not dstart then return end
            local delta = input.Position - dstart
            if math.abs(delta.X) > THRESHOLD or math.abs(delta.Y) > THRESHOLD then didMove = true end
            if didMove then
                CircleBtn.Position = UDim2.new(dpos.X.Scale, dpos.X.Offset + delta.X, dpos.Y.Scale, dpos.Y.Offset + delta.Y)
            end
        end
    end)
end

-- ========================
-- MIN BUTTON
-- ========================
local MinBtn = Instance.new("TextButton")
MinBtn.Name             = "MinBtn"
MinBtn.Parent           = MainFrame
MinBtn.BackgroundColor3 = C.bg
MinBtn.Position         = UDim2.new(1, isMobile and -46 or -42, 0, 4)
MinBtn.Size             = UDim2.new(0, isMobile and 40 or 36, 0, isMobile and 40 or 36)
MinBtn.Font             = FONT_BRAND
MinBtn.Text             = "−"
MinBtn.TextColor3       = C.white
MinBtn.TextSize         = 22
MinBtn.ZIndex           = 15
MinBtn.AutoButtonColor  = false
addCorner(MinBtn, isMobile and 20 or 18)
addStroke(MinBtn, C.white, 1.5)
MinBtn.Activated:Connect(doMinimize)

-- ========================
-- DRAG MAIN FRAME (mobile)
-- ========================
if isMobile then
    local drag, dstart, dpos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            local p = input.Position
            local top = MainFrame.AbsolutePosition
            local size = MainFrame.AbsoluteSize
            local inHeader = p.Y <= top.Y + 48 and p.X < top.X + size.X - 58
            if inHeader then
                drag = true; dstart = p; dpos = MainFrame.Position
            end
        end
    end)
    MainFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then drag = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if drag and input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dstart
            MainFrame.Position = UDim2.new(dpos.X.Scale, dpos.X.Offset + delta.X, dpos.Y.Scale, dpos.Y.Offset + delta.Y)
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
    f.CanvasSize             = UDim2.new(0, 0, 0, 0)
    f.AutomaticCanvasSize     = Enum.AutomaticSize.Y
    f.ScrollingEnabled       = true
    local pad = Instance.new("UIPadding")
    pad.Parent = f
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.PaddingTop = UDim.new(0, 12)
    pad.PaddingBottom = UDim.new(0, 14)
    return f
end

local OthersFrame   = createTabFrame("Others")
local SurvivorFrame = createTabFrame("Survivor")
local ESPFrame      = createTabFrame("ESP")

local tabs = {
    { name = "SURVIVOR", frame = SurvivorFrame },
    { name = "ESP",      frame = ESPFrame      },
    { name = "LAINNYA",  frame = OthersFrame   },
}

local function showTab(name)
    for _, t in pairs(tabs) do t.frame.Visible = (t.name == name) end
end

for _, t in pairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Parent           = TabContainer
    btn.BackgroundColor3 = C.card
    btn.Size             = UDim2.new(1, 0, 0, isMobile and 38 or 36)
    btn.Font             = Enum.Font.GothamMedium
    btn.Text             = t.name
    btn.TextColor3       = C.subtext
    btn.TextSize         = isMobile and 10 or 11
    btn.TextStrokeTransparency = 1
    btn.AutoButtonColor  = false
    addCorner(btn, 9)
    local tabStroke = addStroke(btn, C.border, 1)
    tabStroke.Transparency = 0.42
    local function onTab()
        showTab(t.name)
        for _, other in pairs(TabContainer:GetChildren()) do
            if other:IsA("TextButton") then
                other.TextColor3 = C.subtext
                other.BackgroundColor3 = C.card
                local otherStroke = other:FindFirstChildOfClass("UIStroke")
                if otherStroke then
                    otherStroke.Color = C.border
                    otherStroke.Transparency = 0.42
                end
            end
        end
        btn.TextColor3 = C.white
        btn.BackgroundColor3 = C.accentDim
        tabStroke.Color = C.accent
        tabStroke.Transparency = 0.12
    end
    btn.Activated:Connect(onTab)
    if t.name == "SURVIVOR" then
        btn.TextColor3 = C.white
        btn.BackgroundColor3 = C.accentDim
        tabStroke.Color = C.accent
        tabStroke.Transparency = 0.12
    end
end

-- ========================
-- UI HELPERS
-- ========================
local function createCard(parent, yOffset, height)
    local card = Instance.new("Frame")
    card.Parent = parent; card.BackgroundColor3 = C.card
    card.BorderSizePixel = 0
    card.Position = UDim2.new(0, 0, 0, yOffset)
    card.Size = UDim2.new(1, 0, 0, height)
    addCorner(card, isMobile and 13 or 12)
    local cardStroke = addStroke(card, C.border, 1)
    cardStroke.Transparency = 0.18
    addGradient(card, Color3.fromRGB(27, 31, 38), Color3.fromRGB(19, 22, 28), 90)
    return card
end

local function createToggle(parent, icon, text, yOffset, default, callback)
    local card = createCard(parent, yOffset, TOGGLE_H)
    local hitArea = Instance.new("TextButton")
    hitArea.Parent = card; hitArea.BackgroundTransparency = 1
    hitArea.Size = UDim2.new(1, 0, 1, 0); hitArea.Text = ""
    hitArea.AutoButtonColor = false; hitArea.ZIndex = 2

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Parent = card; iconLbl.BackgroundTransparency = 1
    iconLbl.Position = UDim2.new(0, 10, 0, 0); iconLbl.Size = UDim2.new(0, 28, 1, 0)
    iconLbl.Font = Enum.Font.GothamBold
    iconLbl.Text = icon
    iconLbl.TextColor3 = C.subtext
    iconLbl.TextSize = ICON_SZ
    iconLbl.TextXAlignment = Enum.TextXAlignment.Center
    iconLbl.TextYAlignment = Enum.TextYAlignment.Center

    local label = Instance.new("TextLabel")
    label.Parent = card; label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 44, 0, 0)
    label.Size = UDim2.new(1, -(TOGGLE_W + 66), 1, 0)
    label.Font = Enum.Font.GothamMedium
    label.Text = text
    label.TextWrapped = false
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.TextColor3 = C.text
    label.TextSize = LABEL_SZ
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center

    local switchBg = Instance.new("Frame")
    switchBg.Parent = card; switchBg.BackgroundColor3 = default and C.on or C.off
    switchBg.Position = UDim2.new(1, -(TOGGLE_W + 12), 0.5, -(TOGGLE_SH / 2))
    switchBg.Size = UDim2.new(0, TOGGLE_W, 0, TOGGLE_SH)
    switchBg.ZIndex = 3; addCorner(switchBg, TOGGLE_CR)

    local knob = Instance.new("Frame")
    knob.Parent = switchBg; knob.BackgroundColor3 = C.white
    knob.Size = UDim2.new(0, CIRCLE_SZ, 0, CIRCLE_SZ)
    knob.Position = default
        and UDim2.new(1, -(CIRCLE_SZ + 4), 0.5, -(CIRCLE_SZ / 2))
        or  UDim2.new(0, 4, 0.5, -(CIRCLE_SZ / 2))
    knob.ZIndex = 4; addCorner(knob, CIRCLE_CR)

    local badge = Instance.new("TextLabel")
    badge.Parent = card; badge.BackgroundTransparency = 1
    badge.Position = UDim2.new(1, -(TOGGLE_W + 12), 1, -15)
    badge.Size = UDim2.new(0, TOGGLE_W, 0, 12)
    badge.Visible = false
    badge.Font = FONT_HEAD
    badge.Text = default and "ON" or "OFF"
    badge.TextColor3 = default and C.on or C.subtext
    badge.TextSize = isMobile and 10 or 9
    badge.TextXAlignment = Enum.TextXAlignment.Center
    badge.TextYAlignment = Enum.TextYAlignment.Center
    badge.ZIndex = 4

    local state = default
    local function toggle()
        state = not state
        switchBg.BackgroundColor3 = state and C.on or C.off
        badge.Text = state and "ON" or "OFF"
        badge.TextColor3 = state and C.on or C.subtext
        knob:TweenPosition(
            state and UDim2.new(1, -(CIRCLE_SZ + 4), 0.5, -(CIRCLE_SZ / 2))
                   or  UDim2.new(0, 4, 0.5, -(CIRCLE_SZ / 2)),
            "Out", "Quad", 0.15, true)
        local stroke = card:FindFirstChildOfClass("UIStroke")
        if stroke then
            stroke.Color = state and C.on or C.border
            task.delay(0.3, function()
                if stroke and stroke.Parent then stroke.Color = C.border end
            end)
        end
        callback(state)
    end
    hitArea.Activated:Connect(toggle)
    return function(v)
        state = v
        switchBg.BackgroundColor3 = state and C.on or C.off
        badge.Text = state and "ON" or "OFF"
        badge.TextColor3 = state and C.on or C.subtext
        knob.Position = state
            and UDim2.new(1, -(CIRCLE_SZ + 4), 0.5, -(CIRCLE_SZ / 2))
            or  UDim2.new(0, 4, 0.5, -(CIRCLE_SZ / 2))
    end
end

local function createLabelInput(parent, icon, text, defaultVal, yOffset, callback)
    local card = createCard(parent, yOffset, isMobile and 56 or 42)
    local label = Instance.new("TextLabel")
    label.Parent = card; label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 10, 0, 0); label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Font = FONT_BODY; label.Text = icon .. " " .. text
    label.TextColor3 = C.text; label.TextSize = isMobile and 12 or 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    local input = Instance.new("TextBox")
    input.Parent = card; input.BackgroundColor3 = C.off
    input.Position = UDim2.new(1, -84, 0.5, -(isMobile and 18 or 13))
    input.Size = UDim2.new(0, isMobile and 70 or 64, 0, isMobile and 36 or 26)
    input.Font = FONT_HEAD; input.Text = defaultVal
    input.TextColor3 = C.white; input.TextSize = isMobile and 13 or 11
    input.ClearTextOnFocus = false
    addCorner(input, 6); addStroke(input, C.border, 1)
    input.FocusLost:Connect(function() callback(input.Text) end)
    return input
end

local function createSection(parent, text, yOffset)
    local lbl = Instance.new("TextLabel")
    lbl.Parent = parent; lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 4, 0, yOffset); lbl.Size = UDim2.new(1, -8, 0, 22)
    lbl.Font = Enum.Font.GothamSemibold; lbl.Text = text
    lbl.TextColor3 = C.accent; lbl.TextSize = isMobile and 11 or 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    local line = Instance.new("Frame")
    line.Parent = lbl; line.BackgroundColor3 = C.accent
    line.Size = UDim2.new(0, 24, 0, 2); line.Position = UDim2.new(0, 0, 1, -1)
    line.BorderSizePixel = 0; line.BackgroundTransparency = 0.18
end

-- ========================
-- HOME TAB
-- ========================
local BannerCard = createCard(OthersFrame, 5, 80)
BannerCard.BackgroundColor3 = C.panel
addGradient(BannerCard, Color3.fromRGB(34, 39, 48), Color3.fromRGB(16, 18, 23), 135)
local BannerTitle = Instance.new("TextLabel")
BannerTitle.Parent = BannerCard; BannerTitle.BackgroundTransparency = 1
BannerTitle.Position = UDim2.new(0, 14, 0, 8); BannerTitle.Size = UDim2.new(1, -14, 0, 30)
BannerTitle.Font = FONT_BRAND; BannerTitle.Text = "CUKY PUQY"
BannerTitle.TextColor3 = C.accent; BannerTitle.TextSize = isMobile and 14 or 20
BannerTitle.TextXAlignment = Enum.TextXAlignment.Left
local BannerSub = Instance.new("TextLabel")
BannerSub.Parent = BannerCard; BannerSub.BackgroundTransparency = 1
BannerSub.Position = UDim2.new(0, 14, 0, 36); BannerSub.Size = UDim2.new(1, -14, 0, 18)
BannerSub.Font = FONT_BODY; BannerSub.Text = "MOBILE DELTA UI"
BannerSub.TextColor3 = C.subtext; BannerSub.TextSize = 11
BannerSub.TextXAlignment = Enum.TextXAlignment.Left

createSection(OthersFrame, "KONTROL MENU", 93)
local keybinds = isMobile and {{ key = "CIRCLE", desc = "Buka / Tutup Menu" }}
    or {{ key = "R-CTRL", desc = "Sembunyikan / Tampilkan Menu" }}
for i, kb in ipairs(keybinds) do
    local kCard = createCard(OthersFrame, 118 + (i-1)*48, 40)
    local kLabel = Instance.new("TextLabel")
    kLabel.Parent = kCard; kLabel.BackgroundTransparency = 1
    kLabel.Position = UDim2.new(0, 10, 0, 0); kLabel.Size = UDim2.new(0.6, 0, 1, 0)
    kLabel.Font = FONT_BODY; kLabel.Text = kb.desc
    kLabel.TextColor3 = C.text; kLabel.TextSize = 11
    kLabel.TextXAlignment = Enum.TextXAlignment.Left
    local kBadge = Instance.new("TextLabel")
    kBadge.Parent = kCard; kBadge.BackgroundColor3 = C.off
    kBadge.Position = UDim2.new(1, -84, 0.5, -11); kBadge.Size = UDim2.new(0, 74, 0, 22)
    kBadge.Font = FONT_HEAD; kBadge.Text = kb.key
    kBadge.TextColor3 = C.accent; kBadge.TextSize = 9
    addCorner(kBadge, 4); addStroke(kBadge, C.border, 1)
end

createSection(OthersFrame, "AUTO SAVE CONFIG", 175)
local cfgStatusCard = createCard(OthersFrame, 200, 40)
local cfgStatusLbl = Instance.new("TextLabel")
cfgStatusLbl.Parent = cfgStatusCard; cfgStatusLbl.BackgroundTransparency = 1
cfgStatusLbl.Position = UDim2.new(0, 10, 0, 0); cfgStatusLbl.Size = UDim2.new(1, -10, 1, 0)
cfgStatusLbl.Font = FONT_BODY; cfgStatusLbl.Text = "CONFIG TERSIMPAN OTOMATIS"
cfgStatusLbl.TextColor3 = C.green; cfgStatusLbl.TextSize = 11
cfgStatusLbl.TextXAlignment = Enum.TextXAlignment.Left

local resetCard = createCard(OthersFrame, 248, 40)
local resetBtn = Instance.new("TextButton")
resetBtn.Parent = resetCard; resetBtn.BackgroundTransparency = 1
resetBtn.Size = UDim2.new(1, 0, 1, 0); resetBtn.Font = FONT_HEAD
resetBtn.Text = "RESET CONFIG"; resetBtn.TextColor3 = C.red
resetBtn.TextSize = 11; resetBtn.AutoButtonColor = false

local unloadCard = createCard(OthersFrame, 296, 40)
local unloadBtn  = Instance.new("TextButton")
unloadBtn.Parent = unloadCard; unloadBtn.BackgroundTransparency = 1
unloadBtn.Size = UDim2.new(1, 0, 1, 0); unloadBtn.Font = FONT_HEAD
unloadBtn.Text = "UNLOAD SCRIPT"; unloadBtn.TextColor3 = C.red
unloadBtn.TextSize = 11; unloadBtn.AutoButtonColor = false
unloadBtn.Activated:Connect(_doUnload)

-- ========================
-- SURVIVOR TAB
-- ========================
createSection(SurvivorFrame, "SKILLCHECK", 5)
local updateSkillcheckUI = createToggle(SurvivorFrame, "✓", "Skillcheck Sempurna", 30, cfg.skillcheckEnabled, function(v)
    skillcheckEnabled = v; saveAll()
end)
local updateSkillcheckNotPerfectUI = createToggle(SurvivorFrame, "✗", "Auto Gen (Not Perfect)", 30 + TOGGLE_H + 12, cfg.skillcheckNotPerfectEnabled, function(v)
    skillcheckNotPerfectEnabled = v; saveAll()
end)

-- ========================
-- VISUAL TAB — ESP per kategori
-- ========================
local TH = TOGGLE_H
local GAP = TH + 12

createSection(ESPFrame, "ESP PLAYER", 5)

-- info trap — label kecil di bawah section header
local trapInfoCard = createCard(ESPFrame, 30, 28)
local trapInfoLbl = Instance.new("TextLabel")
trapInfoLbl.Parent = trapInfoCard; trapInfoLbl.BackgroundTransparency = 1
trapInfoLbl.Position = UDim2.new(0, 10, 0, 0); trapInfoLbl.Size = UDim2.new(1, -10, 1, 0)
trapInfoLbl.Font = Enum.Font.Gotham
trapInfoLbl.Text = "TRAP ESP OTOMATIS BERSAMA PLAYER"
trapInfoLbl.TextColor3 = C.orange; trapInfoLbl.TextSize = isMobile and 10 or 10
trapInfoLbl.TextXAlignment = Enum.TextXAlignment.Left

local updateESPPlayerUI = createToggle(ESPFrame, "P", "Player + Trap Highlight", 66, cfg.espPlayer, function(v)
    espPlayer = v; saveAll()
    -- trap ikut espPlayer
    if v then
        scanTraps()
        setAllTrapEnabled(true)
    else
        setAllTrapEnabled(false)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local h = p.Character:FindFirstChild("H")
                if h then h.Enabled = false end
            end
        end
        if IndicatorGui then
            for _, c in ipairs(IndicatorGui:GetChildren()) do c:Destroy() end
        end
    end
end)

createSection(ESPFrame, "ESP OBJEK", 66 + GAP + 8)
local objBase = 66 + GAP + 8 + 28

local updateESPPalletUI = createToggle(ESPFrame, "P", "Pallet",     objBase + GAP*0, cfg.espPallet,    function(v) espPallet    = v; saveAll() end)
local updateESPWindowUI = createToggle(ESPFrame, "W", "Window",     objBase + GAP*1, cfg.espWindow,    function(v) espWindow    = v; saveAll() end)
local updateESPHookUI   = createToggle(ESPFrame, "H", "Hook",       objBase + GAP*2, cfg.espHook,      function(v) espHook      = v; saveAll() end)
local updateESPGenUI    = createToggle(ESPFrame, "G", "Generator",  objBase + GAP*3, cfg.espGenerator, function(v) espGenerator = v; saveAll() end)
local updateESPGateUI   = createToggle(ESPFrame, "E", "Gate",       objBase + GAP*4, cfg.espGate,      function(v) espGate      = v; saveAll() end)

local fovBase = objBase + GAP*5 + 16
createSection(ESPFrame, "FOV", fovBase)
local updateFOVUI = createToggle(ESPFrame, "◎", "Pengubah FOV", fovBase + 28, cfg.fovEnabled, function(v)
    fovEnabled = v
    if not v and not aimZoomActive then
        pcall(function() Camera.FieldOfView = defaultFOV end)
    end
    saveAll()
end)
local fovInput = createLabelInput(ESPFrame, "F", "Target FOV:", tostring(cfg.targetFOV or 100), fovBase + 28 + GAP + 8, function(txt)
    targetFOV = tonumber(txt) or 100; saveAll()
end)

local xhBase = fovBase + 28 + GAP + 8 + (isMobile and 56 or 42) + 16
createSection(ESPFrame, "CROSSHAIR", xhBase)
local updateCrosshairUI = createToggle(ESPFrame, "+", "Custom Crosshair", xhBase + 28, cfg.crosshairEnabled, function(v)
    crosshairEnabled = v; saveAll()
end)

local lightBase = xhBase + 28 + GAP + 12
createSection(ESPFrame, "PENCAHAYAAN", lightBase)
local updateFullBrightUI = createToggle(ESPFrame, "☼", "Full Bright", lightBase + 28, fullBrightEnabled, function(v)
    fullBrightEnabled = v
    applyFullBright(v)
    saveAll()
end)

-- ========================
-- RESET CONFIG
-- ========================
local function doReset()
    espPlayer = false; espPallet = false; espWindow = false
    espHook = false; espGenerator = false; espGate = false
    if not aimZoomActive then
        pcall(function() Camera.FieldOfView = defaultFOV end)
    end
    crosshairEnabled = false; fovEnabled = false; fullBrightEnabled = false
    skillcheckEnabled = false; skillcheckNotPerfectEnabled = false
    targetFOV = 100
    applyFullBright(false)
    saveAll()
    -- clear trap highlights
    for obj in pairs(trapHighlights) do removeTrapHighlight(obj) end
    updateESPPlayerUI(false); updateESPPalletUI(false); updateESPWindowUI(false)
    updateESPHookUI(false); updateESPGenUI(false); updateESPGateUI(false)
    updateFOVUI(false); updateCrosshairUI(false); updateFullBrightUI(false)
    updateSkillcheckUI(false); updateSkillcheckNotPerfectUI(false)
    fovInput.Text = "100"
    cfgStatusLbl.Text = "CONFIG DIRESET"; cfgStatusLbl.TextColor3 = C.accent
    task.delay(2, function()
        cfgStatusLbl.Text = "CONFIG TERSIMPAN OTOMATIS"; cfgStatusLbl.TextColor3 = C.green
    end)
end
resetBtn.Activated:Connect(doReset)

-- ========================
-- CROSSHAIR GUI
-- ========================
local CrosshairGUI = Instance.new("Frame")
CrosshairGUI.Name = "CustomCrosshair"; CrosshairGUI.Parent = ScreenGui
CrosshairGUI.BackgroundColor3 = C.red; CrosshairGUI.BorderSizePixel = 0
CrosshairGUI.Size = UDim2.new(0, 6, 0, 6); CrosshairGUI.Position = UDim2.new(0.5, -3, 0.5, -3)
CrosshairGUI.Visible = false; addCorner(CrosshairGUI, 3)

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
    UserInputService.TouchEnded:Connect(function() isMouseDown = false end)
end

-- ========================
-- ESP — IndicatorGui setup
-- ========================
local function SetupIndicatorGui()
    if PlayerGui:FindFirstChild("ChasedInds") then
        PlayerGui:FindFirstChild("ChasedInds"):Destroy()
    end
    IndicatorGui = Instance.new("ScreenGui")
    IndicatorGui.Name = "ChasedInds"; IndicatorGui.IgnoreGuiInset = true
    IndicatorGui.DisplayOrder = 998; IndicatorGui.Parent = PlayerGui
end

-- ========================
-- ESP — object highlight helper
-- ========================
local function ApplyObjH(object, color, enabled)
    if not enabled then
        local h = object:FindFirstChild("H")
        if h then h.Enabled = false end
        return
    end
    local h = object:FindFirstChild("H") or Instance.new("Highlight")
    h.Name = "H"; h.Adornee = object
    h.FillColor = color; h.OutlineColor = color
    h.FillTransparency = 0.8; h.OutlineTransparency = 0.3
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Enabled = true; h.Parent = object
end

-- ========================
-- ESP — generator progress billboard
-- ========================
local function CreateBillboardTag(text, color, size, textSize)
    local bb = Instance.new("BillboardGui")
    bb.Name = "BitchHook"; bb.AlwaysOnTop = true
    bb.Size = size or UDim2.new(0, 120, 0, 30)
    local lbl = Instance.new("TextLabel")
    lbl.Name = "BitchHook"; lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = text; lbl.TextColor3 = color
    lbl.TextStrokeTransparency = 0; lbl.TextStrokeColor3 = Color3.new(0,0,0)
    lbl.Font = FONT_HEAD; lbl.TextSize = textSize or 10
    lbl.TextWrapped = true; lbl.RichText = true; lbl.Parent = bb
    return bb
end

local function updateGeneratorProgress(generator)
    if not generator or not generator.Parent then return true end
    local percent = GetGameValue(generator, "RepairProgress") or GetGameValue(generator, "Progress") or 0
    local billboard = generator:FindFirstChild("GenBitchHook")
    if percent >= 100 then
        if billboard then billboard:Destroy() end
        local h = generator:FindFirstChild("H") if h then h:Destroy() end
        return true
    end
    if not espGenerator then
        if billboard then billboard.Enabled = false end
        local h = generator:FindFirstChild("H") if h then h.Enabled = false end
        return false
    end
    local cp = math.clamp(percent, 0, 100)
    local finalColor = cp < 50
        and ESPColors.Generator:Lerp(Color3.fromRGB(180, 180, 0), cp / 50)
        or  Color3.fromRGB(180, 180, 0):Lerp(Color3.fromRGB(0, 150, 0), (cp - 50) / 50)
    local percentStr = string.format("[%.2f%%]", percent)
    if not billboard then
        billboard = CreateBillboardTag(percentStr, finalColor)
        billboard.Name = "GenBitchHook"; billboard.StudsOffset = Vector3.new(0, 2, 0)
        billboard.Adornee = generator:FindFirstChild("defaultMaterial", true) or generator
        billboard.Parent = generator
    else
        billboard.Enabled = true
        local lbl = billboard:FindFirstChild("BitchHook") or billboard:FindFirstChildOfClass("TextLabel")
        if lbl then lbl.Text = percentStr; lbl.TextColor3 = finalColor end
    end
    ApplyObjH(generator, ESPColors.Generator, true)
    return false
end

-- ========================
-- ESP — full object refresh (termasuk trap)
-- ========================
local function RefreshObjectESP()
    ActiveGenerators = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "Window" then ApplyObjH(obj, ESPColors.Window, espWindow) end
        -- scan trap sekalian di sini
        if isTrapObject(obj) then applyTrapHighlight(obj) end
    end
    local Map = workspace:FindFirstChild("Map")
    if not Map then return end
    for _, obj in ipairs(Map:GetDescendants()) do
        if obj.Name == "Generator" then
            ApplyObjH(obj, ESPColors.Generator, espGenerator)
            table.insert(ActiveGenerators, obj)
        elseif obj.Name == "Hook" then
            local m = obj:FindFirstChild("Model")
            if m then
                for _, p in ipairs(m:GetDescendants()) do
                    if p:IsA("MeshPart") then ApplyObjH(p, ESPColors.Hook, espHook) end
                end
            end
        elseif obj.Name == "Palletwrong" or obj.Name == "Pallet" then
            ApplyObjH(obj, ESPColors.Pallet, espPallet)
        elseif obj.Name == "Gate" then
            ApplyObjH(obj, ESPColors.Gate, espGate)
        end
    end
    -- sync enabled state trap dengan espPlayer
    setAllTrapEnabled(espPlayer)
end

-- ========================
-- ESP — player highlight + indicators
-- ========================
local function updatePlayerESP(player)
    if not player.Character then
        if IndicatorGui then
            for _, n in ipairs({player.Name.."_Chased", player.Name.."_Killer"}) do
                local obj = IndicatorGui:FindFirstChild(n)
                if obj then obj:Destroy() end
            end
        end
        return
    end

    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not rootPart then return end

    local isKillerPlayer     = isKillerTeam(player)
    local selectedKillerAttr = GetGameValue(player, "SelectedKiller")
    local rawMask            = GetGameValue(player, "Mask") or GetGameValue(player.Character, "Mask")
    local isKnocked          = GetGameValue(player.Character, "Knocked")
    local isHooked           = GetGameValue(player.Character, "IsHooked")
    local isChased           = GetGameValue(player.Character, "IsChased")

    local color
    if isKillerPlayer then
        color = ESPColors.Killer
    elseif isHooked then
        color = ESPColors.Hooked
    elseif humanoid and humanoid.Health < humanoid.MaxHealth then
        color = isKnocked and ESPColors.Knocked or ESPColors.Injured
    else
        color = ESPColors.Survivor
    end

    local h = player.Character:FindFirstChild("H")
    if espPlayer then
        if not h then
            h = Instance.new("Highlight")
            h.Name = "H"; h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.FillTransparency = 0.8; h.OutlineTransparency = 0.3
            h.Parent = player.Character
        end
        h.Adornee = player.Character
        h.FillColor = color; h.OutlineColor = color; h.Enabled = true
    else
        if h then h.Enabled = false end
    end

    -- mask display (killer)
    if espPlayer and isKillerPlayer and string.match(tostring(selectedKillerAttr or ""):lower(), "masked") and rawMask then
        local searchMask = tostring(rawMask):lower()
        local hasMask = false
        for key, name in pairs(MaskNames) do
            if key:lower() == searchMask then
                hasMask = true
                local maskBB = rootPart:FindFirstChild("MaskHook")
                if not maskBB then
                    maskBB = CreateBillboardTag(name, MaskColors[key] or Color3.new(1,1,1), UDim2.new(0, 100, 0, 20), 12)
                    maskBB.Name = "MaskHook"; maskBB.StudsOffset = Vector3.new(0, 3, 0)
                    maskBB.Adornee = rootPart; maskBB.Parent = rootPart
                else
                    local lbl = maskBB:FindFirstChild("BitchHook") or maskBB:FindFirstChildOfClass("TextLabel")
                    if lbl then lbl.Text = name; lbl.TextColor3 = MaskColors[key] or Color3.new(1,1,1) end
                end
                break
            end
        end
        if not hasMask then
            local mb = rootPart:FindFirstChild("MaskHook") if mb then mb:Destroy() end
        end
    else
        local mb = rootPart:FindFirstChild("MaskHook") if mb then mb:Destroy() end
    end

    if not espPlayer or not IndicatorGui or not IndicatorGui.Parent then
        if IndicatorGui then
            for _, n in ipairs({player.Name.."_Chased", player.Name.."_Killer"}) do
                local obj = IndicatorGui:FindFirstChild(n) if obj then obj:Destroy() end
            end
        end
        return
    end

    local chasedLabel2D = IndicatorGui:FindFirstChild(player.Name .. "_Chased")
    if isChased then
        if not chasedLabel2D then
            chasedLabel2D = Instance.new("TextLabel", IndicatorGui)
            chasedLabel2D.Name = player.Name .. "_Chased"
            chasedLabel2D.BackgroundTransparency = 1
            chasedLabel2D.Font = FONT_HEAD; chasedLabel2D.TextSize = 24
            chasedLabel2D.TextStrokeTransparency = 0; chasedLabel2D.AnchorPoint = Vector2.new(0.5, 0.5)
        end
        chasedLabel2D.Text = "!!"; chasedLabel2D.TextColor3 = color
        local screenPos, onScreen = workspace.CurrentCamera:WorldToScreenPoint(rootPart.Position)
        if onScreen then
            chasedLabel2D.Visible = false
        else
            chasedLabel2D.Visible = true
            local vc = workspace.CurrentCamera.ViewportSize / 2
            local dir = Vector2.new(screenPos.X, screenPos.Y) - vc
            if screenPos.Z < 0 then dir = -dir end
            local ms = math.max(math.abs(dir.X) / (vc.X - 30), math.abs(dir.Y) / (vc.Y - 30))
            chasedLabel2D.Position = UDim2.new(0, vc.X + dir.X / (ms == 0 and 1 or ms), 0, vc.Y + dir.Y / (ms == 0 and 1 or ms))
        end
    else
        if chasedLabel2D then chasedLabel2D:Destroy() end
    end

    local killerLabel2D = IndicatorGui:FindFirstChild(player.Name .. "_Killer")
    if isKillerPlayer then
        if not killerLabel2D then
            killerLabel2D = Instance.new("TextLabel", IndicatorGui)
            killerLabel2D.Name = player.Name .. "_Killer"
            killerLabel2D.BackgroundTransparency = 1
            killerLabel2D.Font = FONT_HEAD; killerLabel2D.TextSize = 20
            killerLabel2D.TextStrokeTransparency = 0; killerLabel2D.Size = UDim2.new(0, 40, 0, 40)
            killerLabel2D.AnchorPoint = Vector2.new(0.5, 0.5)
        end
        killerLabel2D.Text = "▲"; killerLabel2D.TextColor3 = color
        local screenPos, onScreen = workspace.CurrentCamera:WorldToScreenPoint(rootPart.Position)
        if not onScreen then
            killerLabel2D.Visible = true
            local vc = workspace.CurrentCamera.ViewportSize / 2
            local dir = Vector2.new(screenPos.X, screenPos.Y) - vc
            if screenPos.Z < 0 then dir = -dir end
            local ms = math.max(math.abs(dir.X) / (vc.X - 30), math.abs(dir.Y) / (vc.Y - 30))
            killerLabel2D.Position = UDim2.new(0, vc.X + dir.X / (ms == 0 and 1 or ms), 0, vc.Y + dir.Y / (ms == 0 and 1 or ms))
        else
            killerLabel2D.Visible = false
        end
    elseif killerLabel2D then
        killerLabel2D:Destroy()
    end
end

-- map auto-refresh
workspace.ChildAdded:Connect(function(c)
    if c.Name == "Map" then task.wait(1); RefreshObjectESP() end
end)

LocalPlayer.CharacterAdded:Connect(function()
    SetupIndicatorGui()
    task.wait(1); RefreshObjectESP()
    if HeartbeatConnection then HeartbeatConnection:Disconnect() end
    if VisibilityConnection then VisibilityConnection:Disconnect() end
    task.wait(0); InitializeAutobuy()
end)

Players.PlayerRemoving:Connect(function(p)
    if not IndicatorGui then return end
    for _, n in ipairs({p.Name.."_Chased", p.Name.."_Killer"}) do
        local obj = IndicatorGui:FindFirstChild(n) if obj then obj:Destroy() end
    end
end)

-- ========================
-- SKILLCHECK
-- ========================
local function GetActionTarget()
    local current = PlayerGui
    for segment in string.gmatch(ActionPath, "[^%.]+") do
        current = current and current:FindFirstChild(segment)
    end
    return current
end

local function TriggerMobileButton()
    local b = GetActionTarget()
    if b and b:IsA("GuiObject") then
        local p, s, i = b.AbsolutePosition, b.AbsoluteSize, GuiService:GetGuiInset()
        local cx = p.X + (s.X/2) + i.X
        local cy = p.Y + (s.Y/2) + i.Y
        -- The overlay can sit above the game's mobile button. Temporarily disable
        -- only this script's ScreenGui while sending the synthetic tap.
        local wasEnabled = ScreenGui and ScreenGui.Enabled
        if wasEnabled then ScreenGui.Enabled = false end
        pcall(function()
            VirtualInputManager:SendTouchEvent(TouchID, 0, cx, cy)
            task.wait(0.01)
            VirtualInputManager:SendTouchEvent(TouchID, 2, cx, cy)
        end)
        if wasEnabled and ScreenGui then ScreenGui.Enabled = true end
    end
end

function InitializeAutobuy()
    task.spawn(function()
        local prompt = PlayerGui:WaitForChild("SkillCheckPromptGui", 10)
        local check  = prompt and prompt:WaitForChild("Check", 10)
        if not check then return end
        local line = check:WaitForChild("Line")
        local goal = check:WaitForChild("Goal")
        if HeartbeatConnection then HeartbeatConnection:Disconnect() end
        local wasInGoal = false
        HeartbeatConnection = RunService.Heartbeat:Connect(function()
            if not ScriptRunning then return end
            if not (LocalPlayer.Team and LocalPlayer.Team.Name == "Survivors")
                or not skillcheckEnabled or not check.Visible then
                wasInGoal = false
                return
            end
            if not line.Parent or not goal.Parent then return end
            local lr = line.Rotation % 360
            local gr = goal.Rotation % 360
            local gs = (gr + 104) % 360
            local ge = (gr + 114) % 360
            local inGoal = (gs > ge and (lr >= gs or lr <= ge))
                or (lr >= gs and lr <= ge)
            if inGoal and not wasInGoal then
                wasInGoal = true
                TriggerMobileButton()
            elseif not inGoal then
                wasInGoal = false
            end
        end)
    end)
end

-- ========================
-- MAIN LOOP
-- ========================
_RenderConnection = RunService.RenderStepped:Connect(function()
    if not ScriptRunning then return end

    -- Respect temporary camera zooms started by the game (for example, aim).
    local currentFOV = Camera and Camera.FieldOfView
    if currentFOV then
        local normalFOV = fovEnabled and math.min(defaultFOV, targetFOV) or defaultFOV
        if aimZoomActive then
            if currentFOV >= normalFOV - 1 then
                aimZoomActive = false
            else
                CrosshairGUI.Visible = crosshairEnabled and not isMobile
                return
            end
        end

        if currentFOV < normalFOV - 2 then
            aimZoomActive = true
        elseif fovEnabled then
            if math.abs(currentFOV - targetFOV) > 0.05 then
                Camera.FieldOfView = targetFOV
            end
        else
            -- Track the game's normal FOV while the custom changer is off.
            defaultFOV = currentFOV
        end
    end
    CrosshairGUI.Visible = crosshairEnabled and not isMobile
end)

_MainHBConnection = RunService.Heartbeat:Connect(function()
    if not ScriptRunning then return end
    local now = tick()
    if now - LastUpdateTick < 0.05 then return end
    LastUpdateTick = now

    if now - LastESPRefresh > 5 then
        LastESPRefresh = now
        RefreshObjectESP()
    end
    -- Re-apply after map scripts or teleports replace the lighting values.
    if fullBrightEnabled and now - LastFullBrightApply >= 0.5 then
        LastFullBrightApply = now
        applyFullBright(true)
    end

    local myChar  = LocalPlayer.Character
    local myRoot  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local killerNearby = false

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            pcall(updatePlayerESP, p)
            if espPlayer and isKillerTeam(p) and myRoot
            and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                if (p.Character.HumanoidRootPart.Position - myRoot.Position).Magnitude < 99 then
                    killerNearby = true
                end
            end
        end
    end

    if myRoot then
        local warn = myRoot:FindFirstChild("KillerWarn")
        if espPlayer and killerNearby then
            if not warn then
                local bb = Instance.new("BillboardGui")
                bb.Name = "KillerWarn"; bb.AlwaysOnTop = true
                bb.Size = UDim2.new(0, 50, 0, 50); bb.StudsOffset = Vector3.new(0, 4, 0)
                bb.Adornee = myRoot; bb.Parent = myRoot
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
                lbl.Text = "!"; lbl.TextColor3 = Color3.fromRGB(255, 0, 0)
                lbl.TextStrokeTransparency = 0; lbl.Font = FONT_HEAD
                lbl.TextSize = 40; lbl.Parent = bb
            end
        elseif warn then
            warn:Destroy()
        end
    end

    for i = #ActiveGenerators, 1, -1 do
        local g = ActiveGenerators[i]
        if g and g.Parent then
            if updateGeneratorProgress(g) then table.remove(ActiveGenerators, i) end
        else
            table.remove(ActiveGenerators, i)
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
    if processed then return end
    if input.KeyCode == hideMenuKey then doMinimize() end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isMouseDown = false
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        isRightMouseDown = false
    end
end)

-- ========================
-- INIT
-- ========================
SetupIndicatorGui()
RefreshObjectESP()
-- scan trap awal kalau espPlayer sudah aktif dari config
if espPlayer then scanTraps() end
InitializeAutobuy()
showTab("SURVIVOR")
