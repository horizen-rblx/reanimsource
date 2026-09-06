-- Zen Reanimations Runner (ZenScript Theme)
-- Loads module.lua and provides 5 unified tabs: Reanims, Favs, Binds, Speed, States + Now Playing bar

local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- ═══════════════════════════════════════════════════
-- ZEN THEME PALETTE
-- ═══════════════════════════════════════════════════
local C = {
    bg              = Color3.fromRGB(0, 0, 0),       -- Pure black
    bgCard          = Color3.fromRGB(10, 10, 10),    -- Deep dark grey
    surface         = Color3.fromRGB(16, 16, 16),    -- Surface grey
    surfaceHover    = Color3.fromRGB(26, 26, 26),    -- Hover grey
    input           = Color3.fromRGB(12, 12, 12),    -- Input background
    accent          = Color3.fromRGB(255, 255, 255), -- Pure white accent
    danger          = Color3.fromRGB(50, 50, 50),    -- Muted dark grey for danger
    dangerHover     = Color3.fromRGB(180, 40, 40),   -- Red hover for unbind/clear
    success         = Color3.fromRGB(255, 255, 255), -- White for success state
    text            = Color3.fromRGB(240, 240, 240), -- Clean white text
    textMuted       = Color3.fromRGB(130, 130, 130), -- Muted grey text
    divider         = Color3.fromRGB(28, 28, 28),    -- Subtle borders
    border          = Color3.fromRGB(38, 38, 38),    -- Card stroke border
    green           = Color3.fromRGB(80, 220, 120),  -- Live playing status
}

local function applyCorner(parent, radius)
    local corner = Instance.new("UICorner", parent)
    corner.CornerRadius = UDim.new(0, radius or 8)
    return corner
end

local function applyStroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke", parent)
    s.Color = color or C.accent
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0.6
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end

local function tween(obj, props, dur, style, dir)
    local info = TweenInfo.new(dur or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

-- Clean up old GUI if it exists
if CoreGui:FindFirstChild("ZenReanimationsRunner") then
    CoreGui.ZenReanimationsRunner:Destroy()
end

-- ═══════════════════════════════════════════════════
-- 1. LOAD MODULE API
-- ═══════════════════════════════════════════════════
local api
local success, result = pcall(function()
    if isfile and isfile("module.lua") then
        return loadstring(readfile("module.lua"))()
    end
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/horizen-rblx/reanimsource/main/module.lua"))()
end)

if success and type(result) == "table" then
    api = result
else
    warn("Zen Reanimations: Failed to load module.lua. Error: " .. tostring(result))
    return
end

-- ═══════════════════════════════════════════════════
-- 2. LOAD ANIMATIONS LIST (Merge Main + Unicorns)
-- ═══════════════════════════════════════════════════
local animations = {}
local anim_success, anim_data = pcall(function()
    return game:HttpGet("https://raw.githubusercontent.com/horizen-rblx/reanimsource/main/animations.json")
end)

if anim_success then
    local decode_success, decoded = pcall(function()
        return HttpService:JSONDecode(anim_data)
    end)
    if decode_success and type(decoded) == "table" then
        for _, item in ipairs(decoded) do
            if item.name and item.path then
                table.insert(animations, {
                    name = item.name,
                    path = item.path,
                    category = item.category or "Reanims"
                })
            end
        end
        -- Sort alphabetically
        table.sort(animations, function(a, b)
            return a.name:lower() < b.name:lower()
        end)
    else
        warn("Zen Reanimations: Failed to parse animations.json")
    end
else
    warn("Zen Reanimations: Failed to download animations.json from GitHub")
end

-- ═══════════════════════════════════════════════════
-- 3. PERSISTENT CONFIGURATION
-- ═══════════════════════════════════════════════════
local CONFIG_FILE = "ZenReanimConfig.json"
local savedConfig = {
    favs = {},
    binds = {},
    states = {},
    speed = 1.0,
    speedBinds = {}
}

if isfile and readfile and isfile(CONFIG_FILE) then
    pcall(function()
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if type(data) == "table" then
            if data.favs then savedConfig.favs = data.favs end
            if data.binds then savedConfig.binds = data.binds end
            if data.states then savedConfig.states = data.states end
            if data.speed then savedConfig.speed = tonumber(data.speed) or 1.0 end
            if data.speedBinds then savedConfig.speedBinds = data.speedBinds end
        end
    end)
end

local function saveConfig()
    if writefile then
        pcall(function()
            writefile(CONFIG_FILE, HttpService:JSONEncode(savedConfig))
        end)
    end
end

-- Preload Favorites in background
task.spawn(function()
    task.wait(2)
    if api and api.preload_animation then
        for animName, _ in pairs(savedConfig.favs) do
            for _, a in ipairs(animations) do
                if a.name == animName then
                    api.preload_animation(a.path)
                    task.wait(0.3)
                    break
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════
-- 4. GUI CONSTRUCTION
-- ═══════════════════════════════════════════════════
local currentSpeed = savedConfig.speed or 1.0
local currentPlayingAnim = nil
local manualAnimationPlaying = false
local currentTab = "Reanims"

local gui = Instance.new("ScreenGui")
gui.Name = "ZenReanimationsRunner"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 440, 0, 540)
mainFrame.Position = UDim2.new(0.5, -220, 0.5, -270)
mainFrame.BackgroundColor3 = C.bgCard
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = gui

applyCorner(mainFrame, 12)
local mainStroke = applyStroke(mainFrame, C.accent, 1.5, 0.2)

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 48)
titleBar.BackgroundColor3 = C.bg
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 20
titleBar.Parent = mainFrame
applyCorner(titleBar, 12)

local titleDivider = Instance.new("Frame")
titleDivider.Size = UDim2.new(1, 0, 0, 1)
titleDivider.Position = UDim2.new(0, 0, 1, -1)
titleDivider.BackgroundColor3 = C.divider
titleDivider.BorderSizePixel = 0
titleDivider.ZIndex = 20
titleDivider.Parent = titleBar

local macBtns = Instance.new("Frame")
macBtns.Size = UDim2.new(0, 50, 1, 0)
macBtns.Position = UDim2.new(0, 14, 0, 0)
macBtns.BackgroundTransparency = 1
macBtns.ZIndex = 21
macBtns.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 12, 0, 12)
closeBtn.Position = UDim2.new(0, 0, 0.5, -6)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
closeBtn.Text = ""
closeBtn.ZIndex = 22
closeBtn.Parent = macBtns
applyCorner(closeBtn, 6)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 12, 0, 12)
minBtn.Position = UDim2.new(0, 18, 0.5, -6)
minBtn.BackgroundColor3 = Color3.fromRGB(255, 190, 60)
minBtn.Text = ""
minBtn.ZIndex = 22
minBtn.Parent = macBtns
applyCorner(minBtn, 6)

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(0, 160, 1, 0)
titleText.Position = UDim2.new(0, 56, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "ZEN <font color=\"rgb(130,130,130)\">REANIM</font>"
titleText.RichText = true
titleText.TextColor3 = C.text
titleText.TextSize = 13
titleText.Font = Enum.Font.GothamBold
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.ZIndex = 21
titleText.Parent = titleBar

-- Enable / Disable Reanimation Capsule Button
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 130, 0, 28)
toggleBtn.Position = UDim2.new(1, -142, 0.5, -14)
toggleBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
toggleBtn.Text = "Enable Reanim"
toggleBtn.TextColor3 = C.text
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 11
toggleBtn.ZIndex = 21
toggleBtn.Parent = titleBar
applyCorner(toggleBtn, 14)
local toggleStroke = applyStroke(toggleBtn, C.border, 1, 0.4)

-- Body Container (houses tabs, page content, and now playing bar; hidden during minimize)
local bodyContainer = Instance.new("Frame")
bodyContainer.Name = "BodyContainer"
bodyContainer.Size = UDim2.new(1, 0, 1, -48)
bodyContainer.Position = UDim2.new(0, 0, 0, 48)
bodyContainer.BackgroundTransparency = 1
bodyContainer.ClipsDescendants = true
bodyContainer.Parent = mainFrame

local modalOverlay = nil
local isMinimized = false

local function toggleMinimize()
    isMinimized = not isMinimized
    if isMinimized then
        bodyContainer.Visible = false
        titleDivider.Visible = false
        if modalOverlay then
            modalOverlay.Visible = false
        end
        tween(mainFrame, {Size = UDim2.new(0, 440, 0, 48)}, 0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    else
        titleDivider.Visible = true
        tween(mainFrame, {Size = UDim2.new(0, 440, 0, 540)}, 0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        task.delay(0.12, function()
            if not isMinimized then
                bodyContainer.Visible = true
            end
        end)
    end
end

minBtn.MouseEnter:Connect(function() tween(minBtn, {BackgroundColor3 = Color3.fromRGB(255, 220, 100)}, 0.15) end)
minBtn.MouseLeave:Connect(function() tween(minBtn, {BackgroundColor3 = Color3.fromRGB(255, 190, 60)}, 0.15) end)
minBtn.MouseButton1Click:Connect(toggleMinimize)

closeBtn.MouseEnter:Connect(function() tween(closeBtn, {BackgroundColor3 = Color3.fromRGB(255, 130, 130)}, 0.15) end)
closeBtn.MouseLeave:Connect(function() tween(closeBtn, {BackgroundColor3 = Color3.fromRGB(255, 90, 90)}, 0.15) end)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Window Dragging
local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
end)

-- ═══════════════════════════════════════════════════
-- 5. 5 UNIFIED TABS SEGMENTED BAR
-- ═══════════════════════════════════════════════════
local tabNames = { "Reanims", "Favs", "Binds", "Speed", "States" }
local tabButtons = {}

local tabsFrame = Instance.new("Frame")
tabsFrame.Size = UDim2.new(1, -28, 0, 32)
tabsFrame.Position = UDim2.new(0, 14, 0, 8)
tabsFrame.BackgroundColor3 = C.input
tabsFrame.Parent = bodyContainer
applyCorner(tabsFrame, 7)
applyStroke(tabsFrame, C.divider, 1, 0)

local tabWidthScale = 1 / #tabNames

local tabIndicator = Instance.new("Frame")
tabIndicator.Size = UDim2.new(tabWidthScale, -4, 1, -6)
tabIndicator.Position = UDim2.new(0, 3, 0, 3)
tabIndicator.BackgroundColor3 = C.surfaceHover
tabIndicator.BorderSizePixel = 0
tabIndicator.Parent = tabsFrame
applyCorner(tabIndicator, 5)
applyStroke(tabIndicator, C.divider, 1, 0.4)

for i, tName in ipairs(tabNames) do
    local tb = Instance.new("TextButton")
    tb.Size = UDim2.new(tabWidthScale, 0, 1, 0)
    tb.Position = UDim2.new((i - 1) * tabWidthScale, 0, 0, 0)
    tb.BackgroundTransparency = 1
    tb.Text = tName
    tb.TextColor3 = (i == 1) and C.text or C.textMuted
    tb.Font = Enum.Font.GothamSemibold
    tb.TextSize = 11
    tb.ZIndex = 5
    tb.Parent = tabsFrame
    tabButtons[tName] = tb
end

-- ═══════════════════════════════════════════════════
-- 6. NOW PLAYING BAR & QUICK STOP BUTTON
-- ═══════════════════════════════════════════════════
local npBar = Instance.new("Frame")
npBar.Size = UDim2.new(1, -28, 0, 30)
npBar.Position = UDim2.new(0, 14, 1, -38)
npBar.BackgroundColor3 = C.surface
npBar.BorderSizePixel = 0
npBar.ZIndex = 15
npBar.Parent = bodyContainer
applyCorner(npBar, 7)
local npStroke = applyStroke(npBar, C.divider, 1, 0.3)

local npDot = Instance.new("Frame")
npDot.Size = UDim2.new(0, 6, 0, 6)
npDot.Position = UDim2.new(0, 12, 0.5, -3)
npDot.BackgroundColor3 = C.textMuted
npDot.BorderSizePixel = 0
npDot.ZIndex = 16
npDot.Parent = npBar
applyCorner(npDot, 3)

local nowPlayingLabel = Instance.new("TextLabel")
nowPlayingLabel.Size = UDim2.new(1, -65, 1, 0)
nowPlayingLabel.Position = UDim2.new(0, 26, 0, 0)
nowPlayingLabel.BackgroundTransparency = 1
nowPlayingLabel.Text = "No animation playing"
nowPlayingLabel.TextColor3 = C.textMuted
nowPlayingLabel.Font = Enum.Font.GothamMedium
nowPlayingLabel.TextSize = 11
nowPlayingLabel.TextXAlignment = Enum.TextXAlignment.Left
nowPlayingLabel.TextTruncate = Enum.TextTruncate.AtEnd
nowPlayingLabel.ZIndex = 16
nowPlayingLabel.Parent = npBar

-- Stop Button (glass circle with square stop icon)
local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(0, 22, 0, 22)
stopBtn.Position = UDim2.new(1, -28, 0.5, -11)
stopBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
stopBtn.Text = ""
stopBtn.ZIndex = 16
stopBtn.Parent = npBar
applyCorner(stopBtn, 11)
local stopStroke = applyStroke(stopBtn, C.divider, 1, 0.3)

local stopIcon = Instance.new("Frame")
stopIcon.Size = UDim2.new(0, 8, 0, 8)
stopIcon.Position = UDim2.new(0.5, -4, 0.5, -4)
stopIcon.BackgroundColor3 = C.textMuted
stopIcon.BorderSizePixel = 0
stopIcon.ZIndex = 17
stopIcon.Parent = stopBtn
applyCorner(stopIcon, 2)

local function updateNowPlayingUI(animName)
    currentPlayingAnim = animName
    if animName and animName ~= "" then
        local displayName = animName:gsub("%.lua$", "")
        nowPlayingLabel.Text = "▶  " .. displayName
        nowPlayingLabel.TextColor3 = C.text
        npDot.BackgroundColor3 = C.green
        stopIcon.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
        tween(stopBtn, {BackgroundColor3 = Color3.fromRGB(35, 20, 20)}, 0.2)
        tween(stopStroke, {Color = Color3.fromRGB(160, 50, 50), Transparency = 0.2}, 0.2)
    else
        nowPlayingLabel.Text = "No animation playing"
        nowPlayingLabel.TextColor3 = C.textMuted
        npDot.BackgroundColor3 = C.textMuted
        stopIcon.BackgroundColor3 = C.textMuted
        tween(stopBtn, {BackgroundColor3 = Color3.fromRGB(24, 24, 24)}, 0.2)
        tween(stopStroke, {Color = C.divider, Transparency = 0.5}, 0.2)
    end
end

stopBtn.MouseButton1Click:Connect(function()
    manualAnimationPlaying = false
    if api and api.stop_animation then
        api.stop_animation()
    end
    updateNowPlayingUI(nil)
end)

api.on_animation_play(function(url)
    local name = nil
    for _, a in ipairs(animations) do
        if a.path == url then name = a.name break end
    end
    updateNowPlayingUI(name or "Playing Animation")
end)

api.on_animation_stop(function()
    updateNowPlayingUI(nil)
end)

-- ═══════════════════════════════════════════════════
-- 7. TAB PANELS CONTAINER
-- ═══════════════════════════════════════════════════
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -28, 1, -90)
contentArea.Position = UDim2.new(0, 14, 0, 46)
contentArea.BackgroundTransparency = 1
contentArea.Parent = bodyContainer

-- PANEL 1: REANIMS & FAVS (Shares animation virtual list)
local listPanel = Instance.new("Frame")
listPanel.Size = UDim2.new(1, 0, 1, 0)
listPanel.BackgroundTransparency = 1
listPanel.Visible = true
listPanel.Parent = contentArea

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, 0, 0, 32)
searchBox.Position = UDim2.new(0, 0, 0, 0)
searchBox.BackgroundColor3 = C.input
searchBox.PlaceholderText = "Search animations..."
searchBox.PlaceholderColor3 = C.textMuted
searchBox.Text = ""
searchBox.TextColor3 = C.text
searchBox.Font = Enum.Font.GothamMedium
searchBox.TextSize = 11
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus = false
searchBox.Parent = listPanel
applyCorner(searchBox, 6)
applyStroke(searchBox, C.divider, 1, 0)

local searchPadding = Instance.new("UIPadding")
searchPadding.PaddingLeft = UDim.new(0, 10)
searchPadding.PaddingRight = UDim.new(0, 10)
searchPadding.Parent = searchBox

local scrollList = Instance.new("ScrollingFrame")
scrollList.Size = UDim2.new(1, 0, 1, -40)
scrollList.Position = UDim2.new(0, 0, 0, 40)
scrollList.BackgroundTransparency = 1
scrollList.BorderSizePixel = 0
scrollList.ScrollBarThickness = 3
scrollList.ScrollBarImageColor3 = C.accent
scrollList.ScrollBarImageTransparency = 0.6
scrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollList.Parent = listPanel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollList

local emptyFavsLabel = Instance.new("TextLabel")
emptyFavsLabel.Size = UDim2.new(1, 0, 0, 60)
emptyFavsLabel.Position = UDim2.new(0, 0, 0.3, 0)
emptyFavsLabel.BackgroundTransparency = 1
emptyFavsLabel.Text = "No favorite animations yet.\nClick the star icon (★) on any animation in the Reanims tab!"
emptyFavsLabel.TextColor3 = C.textMuted
emptyFavsLabel.Font = Enum.Font.GothamMedium
emptyFavsLabel.TextSize = 11
emptyFavsLabel.Visible = false
emptyFavsLabel.Parent = listPanel

-- PANEL 2: BINDS PANEL
local bindsPanel = Instance.new("ScrollingFrame")
bindsPanel.Size = UDim2.new(1, 0, 1, 0)
bindsPanel.BackgroundTransparency = 1
bindsPanel.BorderSizePixel = 0
bindsPanel.ScrollBarThickness = 3
bindsPanel.ScrollBarImageColor3 = C.accent
bindsPanel.ScrollBarImageTransparency = 0.6
bindsPanel.Visible = false
bindsPanel.Parent = contentArea

local bindsLayout = Instance.new("UIListLayout")
bindsLayout.Padding = UDim.new(0, 6)
bindsLayout.SortOrder = Enum.SortOrder.LayoutOrder
bindsLayout.Parent = bindsPanel

local bindsHeader = Instance.new("TextLabel")
bindsHeader.Size = UDim2.new(1, 0, 0, 20)
bindsHeader.BackgroundTransparency = 1
bindsHeader.Text = "Click key button to rebind  |  Click [X] to unbind"
bindsHeader.TextColor3 = C.textMuted
bindsHeader.Font = Enum.Font.GothamMedium
bindsHeader.TextSize = 10
bindsHeader.TextXAlignment = Enum.TextXAlignment.Left
bindsHeader.Parent = bindsPanel

local emptyBindsLabel = Instance.new("TextLabel")
emptyBindsLabel.Size = UDim2.new(1, 0, 0, 60)
emptyBindsLabel.BackgroundTransparency = 1
emptyBindsLabel.Text = "No keybinds assigned yet.\nIn the Reanims tab, click [+] next to any animation to bind a key!"
emptyBindsLabel.TextColor3 = C.textMuted
emptyBindsLabel.Font = Enum.Font.GothamMedium
emptyBindsLabel.TextSize = 11
emptyBindsLabel.Visible = false
emptyBindsLabel.Parent = bindsPanel

-- PANEL 3: SPEED PANEL
local speedPanel = Instance.new("ScrollingFrame")
speedPanel.Size = UDim2.new(1, 0, 1, 0)
speedPanel.BackgroundTransparency = 1
speedPanel.BorderSizePixel = 0
speedPanel.ScrollBarThickness = 3
speedPanel.ScrollBarImageColor3 = C.accent
speedPanel.ScrollBarImageTransparency = 0.6
speedPanel.Visible = false
speedPanel.Parent = contentArea

local speedListLayout = Instance.new("UIListLayout")
speedListLayout.Padding = UDim.new(0, 10)
speedListLayout.SortOrder = Enum.SortOrder.LayoutOrder
speedListLayout.Parent = speedPanel

-- Speed Card 1: Continuous Slider
local sliderCard = Instance.new("Frame")
sliderCard.Size = UDim2.new(1, 0, 0, 78)
sliderCard.BackgroundColor3 = C.bgCard
sliderCard.Parent = speedPanel
applyCorner(sliderCard, 8)
applyStroke(sliderCard, C.divider, 1, 0)

local scTitle = Instance.new("TextLabel")
scTitle.Size = UDim2.new(1, -20, 0, 22)
scTitle.Position = UDim2.new(0, 10, 0, 8)
scTitle.BackgroundTransparency = 1
scTitle.Text = "PLAYBACK SPEED"
scTitle.TextColor3 = C.textMuted
scTitle.Font = Enum.Font.GothamBold
scTitle.TextSize = 10
scTitle.TextXAlignment = Enum.TextXAlignment.Left
scTitle.Parent = sliderCard

local sliderTrack = Instance.new("Frame")
sliderTrack.Size = UDim2.new(1, -130, 0, 6)
sliderTrack.Position = UDim2.new(0, 10, 0, 46)
sliderTrack.BackgroundColor3 = C.surface
sliderTrack.BorderSizePixel = 0
sliderTrack.Parent = sliderCard
applyCorner(sliderTrack, 3)

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(0.3, 0, 1, 0)
sliderFill.BackgroundColor3 = C.accent
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderTrack
applyCorner(sliderFill, 3)

local sliderKnob = Instance.new("Frame")
sliderKnob.Size = UDim2.new(0, 14, 0, 14)
sliderKnob.Position = UDim2.new(1, -7, 0.5, -7)
sliderKnob.BackgroundColor3 = C.text
sliderKnob.BorderSizePixel = 0
sliderKnob.Parent = sliderFill
applyCorner(sliderKnob, 7)

local sliderValLabel = Instance.new("TextLabel")
sliderValLabel.Size = UDim2.new(0, 48, 0, 22)
sliderValLabel.Position = UDim2.new(1, -114, 0, 38)
sliderValLabel.BackgroundColor3 = C.input
sliderValLabel.Text = string.format("%.1fx", currentSpeed)
sliderValLabel.TextColor3 = C.accent
sliderValLabel.Font = Enum.Font.GothamBold
sliderValLabel.TextSize = 10
sliderValLabel.Parent = sliderCard
applyCorner(sliderValLabel, 4)
applyStroke(sliderValLabel, C.divider, 1, 0)

local resetSpeedBtn = Instance.new("TextButton")
resetSpeedBtn.Size = UDim2.new(0, 54, 0, 22)
resetSpeedBtn.Position = UDim2.new(1, -60, 0, 38)
resetSpeedBtn.BackgroundColor3 = C.surface
resetSpeedBtn.Text = "Reset 1.0x"
resetSpeedBtn.TextColor3 = C.text
resetSpeedBtn.Font = Enum.Font.GothamSemibold
resetSpeedBtn.TextSize = 9
resetSpeedBtn.Parent = sliderCard
applyCorner(resetSpeedBtn, 4)
applyStroke(resetSpeedBtn, C.divider, 1, 0)

local function applySpeed(val)
    currentSpeed = math.clamp(math.floor(val * 10) / 10, 0.1, 5.0)
    savedConfig.speed = currentSpeed
    saveConfig()
    sliderValLabel.Text = string.format("%.1fx", currentSpeed)
    local pct = (currentSpeed - 0.1) / (3.0 - 0.1)
    sliderFill.Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
    if api and api.set_animation_speed then
        api.set_animation_speed(currentSpeed)
    end
end

resetSpeedBtn.MouseButton1Click:Connect(function()
    applySpeed(1.0)
end)

local draggingSlider = false
local function updateSliderFromInput(input)
    local relX = math.clamp(input.Position.X - sliderTrack.AbsolutePosition.X, 0, sliderTrack.AbsoluteSize.X)
    local pct = relX / sliderTrack.AbsoluteSize.X
    local spd = 0.1 + (2.9 * pct)
    applySpeed(spd)
end

sliderCard.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = true
        updateSliderFromInput(input)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateSliderFromInput(input)
    end
end)

-- Speed Card 2: Presets & Keybinds
local presetCard = Instance.new("Frame")
presetCard.Size = UDim2.new(1, 0, 0, 110)
presetCard.BackgroundColor3 = C.bgCard
presetCard.Parent = speedPanel
applyCorner(presetCard, 8)
applyStroke(presetCard, C.divider, 1, 0)

local pcTitle = Instance.new("TextLabel")
pcTitle.Size = UDim2.new(1, -20, 0, 20)
pcTitle.Position = UDim2.new(0, 10, 0, 8)
pcTitle.BackgroundTransparency = 1
pcTitle.Text = "SPEED PRESETS & HOTKEYS"
pcTitle.TextColor3 = C.textMuted
pcTitle.Font = Enum.Font.GothamBold
pcTitle.TextSize = 10
pcTitle.TextXAlignment = Enum.TextXAlignment.Left
pcTitle.Parent = presetCard

local pcSubtitle = Instance.new("TextLabel")
pcSubtitle.Size = UDim2.new(1, -20, 0, 14)
pcSubtitle.Position = UDim2.new(0, 10, 0, 26)
pcSubtitle.BackgroundTransparency = 1
pcSubtitle.Text = "Click speed button to apply  |  Click [+] to bind key"
pcSubtitle.TextColor3 = C.textMuted
pcSubtitle.Font = Enum.Font.Gotham
pcSubtitle.TextSize = 9
pcSubtitle.TextXAlignment = Enum.TextXAlignment.Left
pcSubtitle.Parent = presetCard

local speedPresets = { 0.5, 1.0, 1.5, 2.0, 3.0 }
local presetRow = Instance.new("Frame")
presetRow.Size = UDim2.new(1, -20, 0, 52)
presetRow.Position = UDim2.new(0, 10, 0, 48)
presetRow.BackgroundTransparency = 1
presetRow.Parent = presetCard

local currentlyBindingSpeed = nil
local speedBindButtons = {}

local pW = 1 / #speedPresets
for i, spd in ipairs(speedPresets) do
    local sBtn = Instance.new("TextButton")
    sBtn.Size = UDim2.new(pW, -4, 0, 24)
    sBtn.Position = UDim2.new((i - 1) * pW, 2, 0, 0)
    sBtn.BackgroundColor3 = C.surface
    sBtn.Text = string.format("%.1fx", spd)
    sBtn.TextColor3 = C.text
    sBtn.Font = Enum.Font.GothamBold
    sBtn.TextSize = 11
    sBtn.Parent = presetRow
    applyCorner(sBtn, 4)
    applyStroke(sBtn, C.divider, 1, 0)

    sBtn.MouseButton1Click:Connect(function()
        applySpeed(spd)
    end)

    local kBtn = Instance.new("TextButton")
    kBtn.Size = UDim2.new(pW, -4, 0, 20)
    kBtn.Position = UDim2.new((i - 1) * pW, 2, 0, 28)
    kBtn.BackgroundColor3 = C.input
    local bound = savedConfig.speedBinds[tostring(spd)]
    kBtn.Text = bound and ("[" .. bound .. "]") or "[+]"
    kBtn.TextColor3 = bound and C.accent or C.textMuted
    kBtn.Font = Enum.Font.GothamSemibold
    kBtn.TextSize = 9
    kBtn.Parent = presetRow
    applyCorner(kBtn, 4)
    applyStroke(kBtn, C.divider, 1, 0)

    speedBindButtons[tostring(spd)] = kBtn

    kBtn.MouseButton1Click:Connect(function()
        if currentlyBindingSpeed == tostring(spd) then
            currentlyBindingSpeed = nil
            local b = savedConfig.speedBinds[tostring(spd)]
            kBtn.Text = b and ("[" .. b .. "]") or "[+]"
            return
        end
        currentlyBindingSpeed = tostring(spd)
        kBtn.Text = "[?]"
        kBtn.TextColor3 = Color3.fromRGB(255, 180, 50)
    end)
end

-- PANEL 4: STATES PANEL
local statesPanel = Instance.new("ScrollingFrame")
statesPanel.Size = UDim2.new(1, 0, 1, 0)
statesPanel.BackgroundTransparency = 1
statesPanel.BorderSizePixel = 0
statesPanel.ScrollBarThickness = 3
statesPanel.ScrollBarImageColor3 = C.accent
statesPanel.ScrollBarImageTransparency = 0.6
statesPanel.Visible = false
statesPanel.Parent = contentArea

local statesListLayout = Instance.new("UIListLayout")
statesListLayout.Padding = UDim.new(0, 8)
statesListLayout.SortOrder = Enum.SortOrder.LayoutOrder
statesListLayout.Parent = statesPanel

local statesHeader = Instance.new("TextLabel")
statesHeader.Size = UDim2.new(1, 0, 0, 18)
statesHeader.BackgroundTransparency = 1
statesHeader.Text = "CHARACTER STATE ANIMATIONS"
statesHeader.TextColor3 = C.textMuted
statesHeader.Font = Enum.Font.GothamBold
statesHeader.TextSize = 10
statesHeader.TextXAlignment = Enum.TextXAlignment.Left
statesHeader.Parent = statesPanel

local statesSubtitle = Instance.new("TextLabel")
statesSubtitle.Size = UDim2.new(1, 0, 0, 14)
statesSubtitle.BackgroundTransparency = 1
statesSubtitle.Text = "Automatically triggers animations on character movement"
statesSubtitle.TextColor3 = C.textMuted
statesSubtitle.Font = Enum.Font.Gotham
statesSubtitle.TextSize = 9
statesSubtitle.TextXAlignment = Enum.TextXAlignment.Left
statesSubtitle.Parent = statesPanel

local stateTypes = { "Idle", "Walk", "Run", "Jump", "Fall" }
local stateSelectButtons = {}
local modalSelectingState = nil

-- ═══════════════════════════════════════════════════
-- 8. ANIMATION SELECTOR MODAL (For States Tab)
-- ═══════════════════════════════════════════════════
modalOverlay = Instance.new("Frame")
modalOverlay.Size = UDim2.new(1, 0, 1, 0)
modalOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
modalOverlay.BackgroundTransparency = 0.4
modalOverlay.BorderSizePixel = 0
modalOverlay.ZIndex = 50
modalOverlay.Visible = false
modalOverlay.Parent = mainFrame

local modalCard = Instance.new("Frame")
modalCard.Size = UDim2.new(0, 380, 0, 420)
modalCard.Position = UDim2.new(0.5, -190, 0.5, -210)
modalCard.BackgroundColor3 = C.bgCard
modalCard.BorderSizePixel = 0
modalCard.ZIndex = 51
modalCard.Parent = modalOverlay
applyCorner(modalCard, 10)
applyStroke(modalCard, C.border, 1.5, 0)

local modalTitle = Instance.new("TextLabel")
modalTitle.Size = UDim2.new(1, -50, 0, 36)
modalTitle.Position = UDim2.new(0, 14, 0, 6)
modalTitle.BackgroundTransparency = 1
modalTitle.Text = "Select Animation for State"
modalTitle.TextColor3 = C.text
modalTitle.Font = Enum.Font.GothamBold
modalTitle.TextSize = 12
modalTitle.TextXAlignment = Enum.TextXAlignment.Left
modalTitle.ZIndex = 52
modalTitle.Parent = modalCard

local modalCloseBtn = Instance.new("TextButton")
modalCloseBtn.Size = UDim2.new(0, 24, 0, 24)
modalCloseBtn.Position = UDim2.new(1, -34, 0, 10)
modalCloseBtn.BackgroundColor3 = C.surface
modalCloseBtn.Text = "✕"
modalCloseBtn.TextColor3 = C.textMuted
modalCloseBtn.Font = Enum.Font.GothamBold
modalCloseBtn.TextSize = 11
modalCloseBtn.ZIndex = 52
modalCloseBtn.Parent = modalCard
applyCorner(modalCloseBtn, 12)

modalCloseBtn.MouseButton1Click:Connect(function()
    modalOverlay.Visible = false
    modalSelectingState = nil
end)

local modalSearch = Instance.new("TextBox")
modalSearch.Size = UDim2.new(1, -28, 0, 30)
modalSearch.Position = UDim2.new(0, 14, 0, 44)
modalSearch.BackgroundColor3 = C.input
modalSearch.PlaceholderText = "Search animations to assign..."
modalSearch.PlaceholderColor3 = C.textMuted
modalSearch.Text = ""
modalSearch.TextColor3 = C.text
modalSearch.Font = Enum.Font.GothamMedium
modalSearch.TextSize = 11
modalSearch.TextXAlignment = Enum.TextXAlignment.Left
modalSearch.ZIndex = 52
modalSearch.ClearTextOnFocus = false
modalSearch.Parent = modalCard
applyCorner(modalSearch, 6)
applyStroke(modalSearch, C.divider, 1, 0)

local msp = Instance.new("UIPadding")
msp.PaddingLeft = UDim.new(0, 10)
msp.PaddingRight = UDim.new(0, 10)
msp.Parent = modalSearch

local modalList = Instance.new("ScrollingFrame")
modalList.Size = UDim2.new(1, -28, 1, -90)
modalList.Position = UDim2.new(0, 14, 0, 80)
modalList.BackgroundTransparency = 1
modalList.BorderSizePixel = 0
modalList.ScrollBarThickness = 3
modalList.ScrollBarImageColor3 = C.accent
modalList.ScrollBarImageTransparency = 0.6
modalList.ZIndex = 52
modalList.CanvasSize = UDim2.new(0, 0, 0, 0)
modalList.Parent = modalCard

local modalListLayout = Instance.new("UIListLayout")
modalListLayout.Padding = UDim.new(0, 4)
modalListLayout.SortOrder = Enum.SortOrder.LayoutOrder
modalListLayout.Parent = modalList

local function populateModalList(filter)
    for _, c in ipairs(modalList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end

    local term = (filter or ""):lower()
    local count = 0

    for _, a in ipairs(animations) do
        if term == "" or a.name:lower():find(term, 1, true) then
            count = count + 1
            local ab = Instance.new("TextButton")
            ab.Size = UDim2.new(1, -6, 0, 28)
            ab.BackgroundColor3 = C.surface
            ab.Text = a.name
            ab.TextColor3 = C.text
            ab.Font = Enum.Font.GothamMedium
            ab.TextSize = 11
            ab.TextXAlignment = Enum.TextXAlignment.Left
            ab.TextTruncate = Enum.TextTruncate.AtEnd
            ab.ZIndex = 53
            ab.Parent = modalList
            applyCorner(ab, 4)
            applyStroke(ab, C.divider, 1, 0)

            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 10)
            pad.Parent = ab

            ab.MouseButton1Click:Connect(function()
                if modalSelectingState then
                    savedConfig.states[modalSelectingState] = { name = a.name, path = a.path }
                    saveConfig()
                    if stateSelectButtons[modalSelectingState] then
                        stateSelectButtons[modalSelectingState].Text = a.name
                        stateSelectButtons[modalSelectingState].TextColor3 = Color3.fromRGB(100, 220, 120)
                    end
                end
                modalOverlay.Visible = false
                modalSelectingState = nil
            end)
        end
    end
    modalList.CanvasSize = UDim2.new(0, 0, 0, count * 32)
end

modalSearch:GetPropertyChangedSignal("Text"):Connect(function()
    populateModalList(modalSearch.Text)
end)

-- Build States Tab Rows
for _, st in ipairs(stateTypes) do
    local sRow = Instance.new("Frame")
    sRow.Size = UDim2.new(1, 0, 0, 42)
    sRow.BackgroundColor3 = C.bgCard
    sRow.Parent = statesPanel
    applyCorner(sRow, 6)
    applyStroke(sRow, C.divider, 1, 0)

    local stLabel = Instance.new("TextLabel")
    stLabel.Size = UDim2.new(0, 70, 1, 0)
    stLabel.Position = UDim2.new(0, 12, 0, 0)
    stLabel.BackgroundTransparency = 1
    stLabel.Text = st
    stLabel.TextColor3 = C.text
    stLabel.Font = Enum.Font.GothamBold
    stLabel.TextSize = 11
    stLabel.TextXAlignment = Enum.TextXAlignment.Left
    stLabel.Parent = sRow

    local currentAssignment = savedConfig.states[st]
    local sBtn = Instance.new("TextButton")
    sBtn.Size = UDim2.new(1, -150, 0, 26)
    sBtn.Position = UDim2.new(0, 84, 0.5, -13)
    sBtn.BackgroundColor3 = C.surface
    sBtn.Text = currentAssignment and currentAssignment.name or "None"
    sBtn.TextColor3 = currentAssignment and Color3.fromRGB(100, 220, 120) or C.textMuted
    sBtn.Font = Enum.Font.GothamMedium
    sBtn.TextSize = 11
    sBtn.TextXAlignment = Enum.TextXAlignment.Left
    sBtn.TextTruncate = Enum.TextTruncate.AtEnd
    sBtn.Parent = sRow
    applyCorner(sBtn, 4)
    applyStroke(sBtn, C.divider, 1, 0)

    local bp = Instance.new("UIPadding")
    bp.PaddingLeft = UDim.new(0, 8)
    bp.PaddingRight = UDim.new(0, 8)
    bp.Parent = sBtn

    stateSelectButtons[st] = sBtn

    sBtn.MouseButton1Click:Connect(function()
        modalSelectingState = st
        modalTitle.Text = "Assign Animation for: " .. st
        modalSearch.Text = ""
        populateModalList("")
        modalOverlay.Visible = true
    end)

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0, 52, 0, 26)
    clearBtn.Position = UDim2.new(1, -60, 0.5, -13)
    clearBtn.BackgroundColor3 = C.surface
    clearBtn.Text = "Clear"
    clearBtn.TextColor3 = C.textMuted
    clearBtn.Font = Enum.Font.GothamSemibold
    clearBtn.TextSize = 10
    clearBtn.Parent = sRow
    applyCorner(clearBtn, 4)
    applyStroke(clearBtn, C.divider, 1, 0)

    clearBtn.MouseEnter:Connect(function()
        tween(clearBtn, {BackgroundColor3 = C.dangerHover, TextColor3 = C.accent}, 0.15)
    end)
    clearBtn.MouseLeave:Connect(function()
        tween(clearBtn, {BackgroundColor3 = C.surface, TextColor3 = C.textMuted}, 0.15)
    end)

    clearBtn.MouseButton1Click:Connect(function()
        savedConfig.states[st] = nil
        saveConfig()
        sBtn.Text = "None"
        sBtn.TextColor3 = C.textMuted
    end)
end

-- ═══════════════════════════════════════════════════
-- 9. REANIMS & FAVS LIST ENGINE (Fast Virtualized)
-- ═══════════════════════════════════════════════════
local ROW_HEIGHT = 38
local currentlyBinding = nil
local activeOutlineAnim = nil
local animButtons = {}

local function playSelectedAnimation(anim)
    if not (api and api.is_reanimated and api.is_reanimated()) then
        warn("Zen Reanimations: Enable Reanimation first to play animations!")
        return
    end

    if currentPlayingAnim == anim.name then
        manualAnimationPlaying = false
        api.stop_animation()
        activeOutlineAnim = nil
        updateNowPlayingUI(nil)
        return
    end

    manualAnimationPlaying = true
    activeOutlineAnim = anim.name
    api.play_animation(anim.path, currentSpeed)
    updateNowPlayingUI(anim.name)
end

local function populateList()
    for _, child in ipairs(scrollList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    table.clear(animButtons)

    local term = searchBox.Text:lower()
    local displayList = {}

    for _, a in ipairs(animations) do
        if currentTab == "Favs" then
            if savedConfig.favs[a.name] then
                if term == "" or a.name:lower():find(term, 1, true) then
                    table.insert(displayList, a)
                end
            end
        else
            if term == "" or a.name:lower():find(term, 1, true) then
                table.insert(displayList, a)
            end
        end
    end

    if currentTab == "Favs" then
        emptyFavsLabel.Visible = (#displayList == 0)
    else
        emptyFavsLabel.Visible = false
    end

    for i, anim in ipairs(displayList) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, ROW_HEIGHT)
        row.BackgroundColor3 = C.surface
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = scrollList
        applyCorner(row, 6)
        local rowStroke = applyStroke(row, (activeOutlineAnim == anim.name) and C.accent or C.divider, 1, (activeOutlineAnim == anim.name) and 0 or 0.5)

        -- Star Button
        local isFav = savedConfig.favs[anim.name]
        local starBtn = Instance.new("TextButton")
        starBtn.Size = UDim2.new(0, 24, 1, 0)
        starBtn.Position = UDim2.new(0, 4, 0, 0)
        starBtn.BackgroundTransparency = 1
        starBtn.Text = isFav and "★" or "☆"
        starBtn.TextColor3 = isFav and Color3.fromRGB(255, 215, 0) or C.textMuted
        starBtn.Font = Enum.Font.GothamBold
        starBtn.TextSize = 14
        starBtn.Parent = row

        starBtn.MouseButton1Click:Connect(function()
            if savedConfig.favs[anim.name] then
                savedConfig.favs[anim.name] = nil
                starBtn.Text = "☆"
                starBtn.TextColor3 = C.textMuted
            else
                savedConfig.favs[anim.name] = true
                starBtn.Text = "★"
                starBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
            end
            saveConfig()
            if currentTab == "Favs" then
                populateList()
            end
        end)

        -- Play Button (Animation Title)
        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.new(1, -78, 1, 0)
        playBtn.Position = UDim2.new(0, 30, 0, 0)
        playBtn.BackgroundTransparency = 1
        playBtn.Text = anim.name
        playBtn.TextColor3 = (activeOutlineAnim == anim.name) and C.accent or C.text
        playBtn.Font = (activeOutlineAnim == anim.name) and Enum.Font.GothamBold or Enum.Font.GothamMedium
        playBtn.TextSize = 11
        playBtn.TextXAlignment = Enum.TextXAlignment.Left
        playBtn.TextTruncate = Enum.TextTruncate.AtEnd
        playBtn.Parent = row

        animButtons[anim.name] = { stroke = rowStroke, btn = playBtn, star = starBtn }

        playBtn.MouseEnter:Connect(function()
            if activeOutlineAnim ~= anim.name then
                tween(row, {BackgroundColor3 = C.surfaceHover}, 0.15)
            end
        end)
        playBtn.MouseLeave:Connect(function()
            if activeOutlineAnim ~= anim.name then
                tween(row, {BackgroundColor3 = C.surface}, 0.15)
            end
        end)
        playBtn.MouseButton1Click:Connect(function()
            playSelectedAnimation(anim)
            for aName, widgets in pairs(animButtons) do
                local isActive = (activeOutlineAnim == aName)
                widgets.stroke.Color = isActive and C.accent or C.divider
                widgets.stroke.Transparency = isActive and 0 or 0.5
                widgets.btn.TextColor3 = isActive and C.accent or C.text
                widgets.btn.Font = isActive and Enum.Font.GothamBold or Enum.Font.GothamMedium
            end
        end)

        -- Keybind Button
        local keyBtn = Instance.new("TextButton")
        keyBtn.Size = UDim2.new(0, 38, 0, 22)
        keyBtn.Position = UDim2.new(1, -44, 0.5, -11)
        keyBtn.BackgroundColor3 = C.input
        local boundKey = savedConfig.binds[anim.name]
        keyBtn.Text = boundKey and ("[" .. boundKey .. "]") or "[+]"
        keyBtn.TextColor3 = boundKey and C.accent or C.textMuted
        keyBtn.Font = Enum.Font.GothamSemibold
        keyBtn.TextSize = 10
        keyBtn.Parent = row
        applyCorner(keyBtn, 4)
        applyStroke(keyBtn, C.divider, 1, 0)

        keyBtn.MouseButton1Click:Connect(function()
            if currentlyBinding and currentlyBinding.name == anim.name then
                currentlyBinding = nil
                local b = savedConfig.binds[anim.name]
                keyBtn.Text = b and ("[" .. b .. "]") or "[+]"
                keyBtn.TextColor3 = b and C.accent or C.textMuted
                return
            end
            currentlyBinding = { name = anim.name, btn = keyBtn }
            keyBtn.Text = "[?]"
            keyBtn.TextColor3 = Color3.fromRGB(255, 180, 50)
        end)
    end

    scrollList.CanvasSize = UDim2.new(0, 0, 0, #displayList * (ROW_HEIGHT + 4))
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    populateList()
end)

-- ═══════════════════════════════════════════════════
-- 10. BINDS LIST ENGINE
-- ═══════════════════════════════════════════════════
local function populateBindsList()
    for _, child in ipairs(bindsPanel:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local boundItems = {}
    for animName, keyName in pairs(savedConfig.binds) do
        -- Find path
        local path = nil
        for _, a in ipairs(animations) do
            if a.name == animName then path = a.path break end
        end
        if path then
            table.insert(boundItems, { name = animName, path = path, key = keyName })
        end
    end

    table.sort(boundItems, function(a, b)
        return a.name:lower() < b.name:lower()
    end)

    emptyBindsLabel.Visible = (#boundItems == 0)

    for i, item in ipairs(boundItems) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, 36)
        row.BackgroundColor3 = C.surface
        row.BorderSizePixel = 0
        row.LayoutOrder = i + 1
        row.Parent = bindsPanel
        applyCorner(row, 6)
        applyStroke(row, C.divider, 1, 0.4)

        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.new(1, -120, 1, 0)
        playBtn.Position = UDim2.new(0, 12, 0, 0)
        playBtn.BackgroundTransparency = 1
        playBtn.Text = item.name
        playBtn.TextColor3 = C.text
        playBtn.Font = Enum.Font.GothamMedium
        playBtn.TextSize = 11
        playBtn.TextXAlignment = Enum.TextXAlignment.Left
        playBtn.TextTruncate = Enum.TextTruncate.AtEnd
        playBtn.Parent = row

        playBtn.MouseButton1Click:Connect(function()
            playSelectedAnimation(item)
        end)

        local keyBtn = Instance.new("TextButton")
        keyBtn.Size = UDim2.new(0, 48, 0, 24)
        keyBtn.Position = UDim2.new(1, -100, 0.5, -12)
        keyBtn.BackgroundColor3 = C.input
        keyBtn.Text = "[" .. item.key .. "]"
        keyBtn.TextColor3 = C.accent
        keyBtn.Font = Enum.Font.GothamBold
        keyBtn.TextSize = 10
        keyBtn.Parent = row
        applyCorner(keyBtn, 4)
        applyStroke(keyBtn, C.divider, 1, 0)

        keyBtn.MouseButton1Click:Connect(function()
            if currentlyBinding and currentlyBinding.name == item.name then
                currentlyBinding = nil
                keyBtn.Text = "[" .. item.key .. "]"
                keyBtn.TextColor3 = C.accent
                return
            end
            currentlyBinding = { name = item.name, btn = keyBtn }
            keyBtn.Text = "[?]"
            keyBtn.TextColor3 = Color3.fromRGB(255, 180, 50)
        end)

        local unbindBtn = Instance.new("TextButton")
        unbindBtn.Size = UDim2.new(0, 42, 0, 24)
        unbindBtn.Position = UDim2.new(1, -48, 0.5, -12)
        unbindBtn.BackgroundColor3 = C.surface
        unbindBtn.Text = "Unbind"
        unbindBtn.TextColor3 = C.textMuted
        unbindBtn.Font = Enum.Font.GothamSemibold
        unbindBtn.TextSize = 9
        unbindBtn.Parent = row
        applyCorner(unbindBtn, 4)
        applyStroke(unbindBtn, C.divider, 1, 0)

        unbindBtn.MouseEnter:Connect(function()
            tween(unbindBtn, {BackgroundColor3 = C.dangerHover, TextColor3 = C.accent}, 0.15)
        end)
        unbindBtn.MouseLeave:Connect(function()
            tween(unbindBtn, {BackgroundColor3 = C.surface, TextColor3 = C.textMuted}, 0.15)
        end)
        unbindBtn.MouseButton1Click:Connect(function()
            savedConfig.binds[item.name] = nil
            saveConfig()
            populateBindsList()
        end)
    end

    bindsPanel.CanvasSize = UDim2.new(0, 0, 0, 26 + #boundItems * 42)
end

-- ═══════════════════════════════════════════════════
-- 11. SWITCH TABS LOGIC
-- ═══════════════════════════════════════════════════
local function switchTab(tab)
    currentTab = tab

    for i, tName in ipairs(tabNames) do
        local tb = tabButtons[tName]
        if tb then
            tb.TextColor3 = (tName == tab) and C.text or C.textMuted
            if tName == tab then
                tween(tabIndicator, {
                    Position = UDim2.new((i - 1) * tabWidthScale, 3, 0, 3),
                    Size = UDim2.new(tabWidthScale, -6, 1, -6)
                }, 0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            end
        end
    end

    listPanel.Visible   = (tab == "Reanims" or tab == "Favs")
    bindsPanel.Visible  = (tab == "Binds")
    speedPanel.Visible  = (tab == "Speed")
    statesPanel.Visible = (tab == "States")

    if tab == "Reanims" or tab == "Favs" then
        populateList()
    elseif tab == "Binds" then
        populateBindsList()
    end
end

for tName, tb in pairs(tabButtons) do
    tb.MouseButton1Click:Connect(function()
        switchTab(tName)
    end)
end

-- ═══════════════════════════════════════════════════
-- 12. CHARACTER STATE MACHINE (States Engine)
-- ═══════════════════════════════════════════════════
local lastLogicalState = nil
local stateThrottle = 0

RunService.Heartbeat:Connect(function()
    if not (api and api.is_reanimated and api.is_reanimated()) then return end
    if manualAnimationPlaying then return end
    if not (savedConfig.states and next(savedConfig.states)) then return end

    stateThrottle = stateThrottle + 1
    if stateThrottle % 2 ~= 0 then return end -- 30Hz evaluation

    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    local hs = hum:GetState()
    local logical = "Idle"

    if hs == Enum.HumanoidStateType.Jumping then
        logical = "Jump"
    elseif hs == Enum.HumanoidStateType.Freefall then
        if hrp.AssemblyLinearVelocity.Y > 0.1 then
            logical = "Jump"
        else
            logical = "Fall"
        end
    else
        local vel = hrp.AssemblyLinearVelocity
        local horizSpeed = Vector2.new(vel.X, vel.Z).Magnitude
        if horizSpeed > 14 then
            logical = "Run"
        elseif horizSpeed > 1.5 then
            logical = "Walk"
        else
            logical = "Idle"
        end
    end

    if logical ~= lastLogicalState then
        lastLogicalState = logical
        local assigned = savedConfig.states[logical]
        if assigned and assigned.path then
            api.play_animation(assigned.path, currentSpeed)
            updateNowPlayingUI("[" .. logical .. "] " .. assigned.name)
        else
            api.stop_animation()
            updateNowPlayingUI(nil)
        end
    end
end)

-- ═══════════════════════════════════════════════════
-- 13. GLOBAL KEYBIND HANDLER
-- ═══════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gpe)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    -- Check if listening to bind an animation
    if currentlyBinding then
        local kName = input.KeyCode.Name
        savedConfig.binds[currentlyBinding.name] = kName
        saveConfig()
        if currentlyBinding.btn then
            currentlyBinding.btn.Text = "[" .. kName .. "]"
            currentlyBinding.btn.TextColor3 = C.accent
        end
        currentlyBinding = nil
        return
    end

    -- Check if listening to bind a speed preset
    if currentlyBindingSpeed then
        local kName = input.KeyCode.Name
        savedConfig.speedBinds[currentlyBindingSpeed] = kName
        saveConfig()
        local btn = speedBindButtons[currentlyBindingSpeed]
        if btn then
            btn.Text = "[" .. kName .. "]"
            btn.TextColor3 = C.accent
        end
        currentlyBindingSpeed = nil
        return
    end

    if gpe then return end

    -- Check speed preset keybinds
    for spdStr, kName in pairs(savedConfig.speedBinds) do
        if input.KeyCode.Name == kName then
            applySpeed(tonumber(spdStr) or 1.0)
            return
        end
    end

    -- Check animation keybinds
    for animName, kName in pairs(savedConfig.binds) do
        if input.KeyCode.Name == kName then
            for _, a in ipairs(animations) do
                if a.name == animName then
                    playSelectedAnimation(a)
                    return
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════
-- 14. TOGGLE REANIMATION BUTTON LOGIC
-- ═══════════════════════════════════════════════════
local function updateReanimButtonState()
    local isReanimated = api.is_reanimated()
    if isReanimated then
        toggleBtn.Text = "Disable Reanim"
        toggleBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        toggleStroke.Color = Color3.fromRGB(160, 160, 160)
        toggleStroke.Transparency = 0.2
    else
        toggleBtn.Text = "Enable Reanim"
        toggleBtn.TextColor3 = C.text
        toggleBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
        toggleStroke.Color = C.border
        toggleStroke.Transparency = 0.4
    end
end

toggleBtn.MouseButton1Click:Connect(function()
    local isReanimated = api.is_reanimated()
    local newState = not isReanimated

    toggleBtn.Text = newState and "Reanimating..." or "Disabling..."
    toggleBtn.TextColor3 = C.textMuted

    task.spawn(function()
        local err = api.reanimate(newState)
        if err and typeof(err) == "string" and err ~= "Already reanimated." then
            warn("Zen Reanimations: " .. err)
        end
        updateReanimButtonState()
        if not newState then
            manualAnimationPlaying = false
            updateNowPlayingUI(nil)
        end
    end)
end)

-- Initialize
updateReanimButtonState()
applySpeed(currentSpeed)
populateList()
