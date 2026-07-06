-- Zen Reanimations Runner (ZenScript Theme)
-- Loads local module.lua and animation files

local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- ═══════════════════════════════════════════════════
-- ZEN THEME PALETTE
-- ═══════════════════════════════════════════════════
local C = {
    bg              = Color3.fromRGB(8, 8, 8),
    bgCard          = Color3.fromRGB(14, 14, 14),
    surface         = Color3.fromRGB(20, 20, 20),
    surfaceHover    = Color3.fromRGB(28, 28, 28),
    input           = Color3.fromRGB(24, 24, 24),
    accent          = Color3.fromRGB(245, 190, 75),
    danger          = Color3.fromRGB(230, 70, 70),
    success         = Color3.fromRGB(80, 220, 140),
    text            = Color3.fromRGB(220, 220, 228),
    textMuted       = Color3.fromRGB(100, 100, 115),
    divider         = Color3.fromRGB(35, 35, 45)
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

local function tween(obj, props, dur)
    local info = TweenInfo.new(dur or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(obj, info, props):Play()
end

-- Clean up old GUI if it exists
if CoreGui:FindFirstChild("ZenReanimationsRunner") then
    CoreGui.ZenReanimationsRunner:Destroy()
end

-- 1. Load the Cloud Module
local api
local success, result = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/horizen-rblx/reanimsource/main/module.lua"))()
end)

if success and type(result) == "table" then
    api = result
else
    warn("Zen Reanimations: Failed to load module.lua from GitHub. Error: " .. tostring(result))
    return
end

-- 2. Load Animations List from Cloud
local animations = {}
local HttpService = game:GetService("HttpService")

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
                table.insert(animations, item)
            end
        end
    else
        warn("Zen Reanimations: Failed to parse animations.json")
    end
else
    warn("Zen Reanimations: Failed to download animations.json from GitHub")
end

local CONFIG_FILE = "ZenReanimConfig.json"
local savedConfig = { favs = {}, binds = {} }

if isfile and readfile and isfile(CONFIG_FILE) then
    pcall(function()
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if data.favs then savedConfig.favs = data.favs end
        if data.binds then savedConfig.binds = data.binds end
    end)
end

local function saveConfig()
    if writefile then
        pcall(function()
            writefile(CONFIG_FILE, HttpService:JSONEncode(savedConfig))
        end)
    end
end


-- Background Fetch Favorites
task.spawn(function()
    task.wait(2) -- Let UI load first
    if api and api.preload_animation then
        for animName, _ in pairs(savedConfig.favs) do
            local path = nil
            for _, a in ipairs(animations) do
                if a.name == animName then path = a.path break end
            end
            if path then
                api.preload_animation(path)
                task.wait(0.5) -- Prevent network spam
            end
        end
    end
end)

-- 3. Create GUI
local gui = Instance.new("ScreenGui")
gui.Name = "ZenReanimationsRunner"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 420, 0, 520)
mainFrame.Position = UDim2.new(0.5, -210, 0.5, -260)
mainFrame.BackgroundColor3 = C.bgCard
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = gui

applyCorner(mainFrame, 12)
local mainStroke = applyStroke(mainFrame, C.accent, 2.0, 0)

local strokeGradient = Instance.new("UIGradient")
strokeGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.45, 1),
    NumberSequenceKeypoint.new(0.5, 0),
    NumberSequenceKeypoint.new(0.55, 1),
    NumberSequenceKeypoint.new(1, 1)
})
strokeGradient.Color = ColorSequence.new(C.accent)
strokeGradient.Parent = mainStroke

task.spawn(function()
    while mainStroke and mainStroke.Parent do
        if strokeGradient then
            strokeGradient.Rotation = (strokeGradient.Rotation + 2.5) % 360
        end
        task.wait()
    end
end)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = C.surface
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
applyCorner(titleBar, 12)

local titleBarMask = Instance.new("Frame")
titleBarMask.Size = UDim2.new(1, 0, 0, 12)
titleBarMask.Position = UDim2.new(0, 0, 1, -12)
titleBarMask.BackgroundColor3 = C.surface
titleBarMask.BorderSizePixel = 0
titleBarMask.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 12, 0, 12)
closeBtn.Position = UDim2.new(0, 15, 0.5, -6)
closeBtn.BackgroundColor3 = C.danger
closeBtn.Text = ""
closeBtn.AutoButtonColor = false
closeBtn.Parent = titleBar
applyCorner(closeBtn, 6)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 12, 0, 12)
minBtn.Position = UDim2.new(0, 35, 0.5, -6)
minBtn.BackgroundColor3 = C.accent
minBtn.Text = ""
minBtn.AutoButtonColor = false
minBtn.Parent = titleBar
applyCorner(minBtn, 6)

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(0, 140, 1, 0)
titleText.Position = UDim2.new(0, 55, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "Zen Reanimations"
titleText.TextColor3 = C.text
titleText.TextSize = 14
titleText.Font = Enum.Font.GothamBold
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

local controlsFrame = Instance.new("Frame")
controlsFrame.Size = UDim2.new(0, 205, 0, 30)
controlsFrame.Position = UDim2.new(1, -215, 0.5, -15)
controlsFrame.BackgroundTransparency = 1
controlsFrame.Parent = titleBar

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(1, 0, 1, 0)
toggleBtn.Position = UDim2.new(0, 0, 0, 0)
toggleBtn.BackgroundColor3 = C.bgCard
toggleBtn.Text = "Enable Reanim"
toggleBtn.TextColor3 = C.text
toggleBtn.Font = Enum.Font.GothamSemibold
toggleBtn.TextSize = 12
toggleBtn.Parent = controlsFrame
applyCorner(toggleBtn, 6)
applyStroke(toggleBtn, C.divider, 1, 0)

local isMinimized = false
minBtn.MouseEnter:Connect(function() tween(minBtn, {BackgroundColor3 = Color3.fromRGB(255, 230, 140)}, 0.15) end)
minBtn.MouseLeave:Connect(function() tween(minBtn, {BackgroundColor3 = C.accent}, 0.15) end)
minBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        tween(mainFrame, {Size = UDim2.new(0, 420, 0, 50)}, 0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    else
        tween(mainFrame, {Size = UDim2.new(0, 420, 0, 520)}, 0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    end
end)

closeBtn.MouseEnter:Connect(function() tween(closeBtn, {BackgroundColor3 = Color3.fromRGB(255, 100, 100)}, 0.15) end)
closeBtn.MouseLeave:Connect(function() tween(closeBtn, {BackgroundColor3 = C.danger}, 0.15) end)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Dragging logic
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

-- Tabs Area
local currentSpeed = 1.0

local tabsFrame = Instance.new("Frame")
tabsFrame.Size = UDim2.new(1, -40, 0, 30)
tabsFrame.Position = UDim2.new(0, 20, 0, 70)
tabsFrame.BackgroundTransparency = 1
tabsFrame.Parent = mainFrame

local tabAll = Instance.new("TextButton")
tabAll.Size = UDim2.new(0.5, -5, 1, 0)
tabAll.BackgroundColor3 = C.surfaceHover
tabAll.Text = "All"
tabAll.TextColor3 = C.text
tabAll.Font = Enum.Font.GothamSemibold
tabAll.TextSize = 13
tabAll.Parent = tabsFrame
applyCorner(tabAll, 6)
local tabAllStroke = applyStroke(tabAll, C.accent, 1, 0)

local tabFavs = Instance.new("TextButton")
tabFavs.Size = UDim2.new(0.5, -5, 1, 0)
tabFavs.Position = UDim2.new(0.5, 5, 0, 0)
tabFavs.BackgroundColor3 = C.surface
tabFavs.Text = "Favorites"
tabFavs.TextColor3 = C.textMuted
tabFavs.Font = Enum.Font.GothamSemibold
tabFavs.TextSize = 13
tabFavs.Parent = tabsFrame
applyCorner(tabFavs, 6)
local tabFavsStroke = applyStroke(tabFavs, C.divider, 1, 0)

local currentTab = "All"

-- Search Bar
-- Speed Slider
local sliderContainer = Instance.new("Frame")
sliderContainer.Size = UDim2.new(1, -40, 0, 36)
sliderContainer.Position = UDim2.new(0, 20, 0, 110)
sliderContainer.BackgroundColor3 = C.input
sliderContainer.Parent = mainFrame
applyCorner(sliderContainer, 6)
applyStroke(sliderContainer, C.divider, 1, 0)

local sliderLabel = Instance.new("TextLabel")
sliderLabel.Size = UDim2.new(0, 50, 1, 0)
sliderLabel.Position = UDim2.new(0, 10, 0, 0)
sliderLabel.BackgroundTransparency = 1
sliderLabel.Text = "Speed"
sliderLabel.TextColor3 = C.textMuted
sliderLabel.Font = Enum.Font.GothamSemibold
sliderLabel.TextSize = 12
sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
sliderLabel.Parent = sliderContainer

local sliderTrack = Instance.new("Frame")
sliderTrack.Size = UDim2.new(1, -120, 0, 4)
sliderTrack.Position = UDim2.new(0, 60, 0.5, -2)
sliderTrack.BackgroundColor3 = C.bgCard
sliderTrack.BorderSizePixel = 0
sliderTrack.Parent = sliderContainer
applyCorner(sliderTrack, 2)

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(0.3, 0, 1, 0) -- default ~1.0 on a 0.1 to 3.0 scale
sliderFill.BackgroundColor3 = C.accent
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderTrack
applyCorner(sliderFill, 2)

local sliderKnob = Instance.new("Frame")
sliderKnob.Size = UDim2.new(0, 12, 0, 12)
sliderKnob.Position = UDim2.new(1, -6, 0.5, -6)
sliderKnob.BackgroundColor3 = C.text
sliderKnob.BorderSizePixel = 0
sliderKnob.Parent = sliderFill
applyCorner(sliderKnob, 6)

local sliderValue = Instance.new("TextLabel")
sliderValue.Size = UDim2.new(0, 40, 1, 0)
sliderValue.Position = UDim2.new(1, -45, 0, 0)
sliderValue.BackgroundTransparency = 1
sliderValue.Text = "1.0x"
sliderValue.TextColor3 = C.text
sliderValue.Font = Enum.Font.GothamBold
sliderValue.TextSize = 12
sliderValue.TextXAlignment = Enum.TextXAlignment.Right
sliderValue.Parent = sliderContainer

local draggingSlider = false
local function updateSlider(input)
    local relX = math.clamp(input.Position.X - sliderTrack.AbsolutePosition.X, 0, sliderTrack.AbsoluteSize.X)
    local percent = relX / sliderTrack.AbsoluteSize.X
    sliderFill.Size = UDim2.new(percent, 0, 1, 0)
    
    local minSpd, maxSpd = 0.1, 3.0
    local spd = minSpd + ((maxSpd - minSpd) * percent)
    currentSpeed = math.floor(spd * 10) / 10
    sliderValue.Text = string.format("%.1fx", currentSpeed)
    
    if api.is_reanimated() then
        api.set_animation_speed(currentSpeed)
    end
end

sliderContainer.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = true
        updateSlider(input)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateSlider(input)
    end
end)

-- Search Bar
local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -40, 0, 36)
searchBox.Position = UDim2.new(0, 20, 0, 150)
searchBox.BackgroundColor3 = C.input
searchBox.Text = ""
searchBox.PlaceholderText = "Search Animations..."
searchBox.PlaceholderColor3 = C.textMuted
searchBox.TextColor3 = C.text
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 13
searchBox.Parent = mainFrame
applyCorner(searchBox, 6)
applyStroke(searchBox, C.divider, 1, 0)

-- Animations List
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -30, 1, -196)
scrollFrame.Position = UDim2.new(0, 20, 0, 196)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = C.textMuted
scrollFrame.BorderSizePixel = 0
scrollFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

local animButtons = {}

local function setReanimState(state)
    api.reanimate(state)
    if state then
        toggleBtn.Text = "Disable Reanim"
        toggleBtn.TextColor3 = C.success
    else
        toggleBtn.Text = "Enable Reanim"
        toggleBtn.TextColor3 = C.text
    end
end

local isProcessing = false

local function toggleReanim()
    if isProcessing then return end
    isProcessing = true
    local isReanim = api.is_reanimated()
    setReanimState(not isReanim)
    task.wait(0.2)
    isProcessing = false
end

local activeAnim = nil
local currentlyBinding = nil

local function toggleAnimation(animName, animPath)
    if isProcessing then return end
    isProcessing = true
    if activeAnim == animName then
        api.stop_animation()
        activeAnim = nil
        isProcessing = false
    else
        task.spawn(function()
            if not api.is_reanimated() then
                setReanimState(true)
                local clone = api.get_clone()
                if clone then
                    local waited = 0
                    while not clone:FindFirstChild("HumanoidRootPart") and waited < 1.0 do
                        waited = waited + task.wait(0.05)
                    end
                    task.wait(0.15) 
                else
                    task.wait(0.5) 
                end
            end
            
            local result = api.play_animation(animPath, currentSpeed)
            if type(result) == "string" then
                warn("Reanimations Error:", result)
            else
                activeAnim = animName
            end
            task.wait(0.1)
            isProcessing = false
        end)
    end
end

local function populateList(filterText)
    for _, btn in ipairs(animButtons) do
        btn:Destroy()
    end
    table.clear(animButtons)
    
    filterText = filterText:lower()
    
    for _, anim in ipairs(animations) do
        local isFav = savedConfig.favs[anim.name]
        if currentTab == "Favorites" and not isFav then continue end
        
        if filterText == "" or anim.name:lower():find(filterText) then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -10, 0, 36)
            btn.BackgroundColor3 = C.surface
            btn.Text = "        " .. anim.name
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.TextColor3 = C.text
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 13
            btn.AutoButtonColor = false
            btn.Parent = scrollFrame
            applyCorner(btn, 6)
            
            -- Star Icon
            local starBtn = Instance.new("TextButton")
            starBtn.Size = UDim2.new(0, 30, 1, 0)
            starBtn.Position = UDim2.new(0, 0, 0, 0)
            starBtn.BackgroundTransparency = 1
            starBtn.Text = isFav and "★" or "☆"
            starBtn.TextColor3 = isFav and C.accent or C.textMuted
            starBtn.TextSize = 18
            starBtn.Font = Enum.Font.GothamBold
            starBtn.Parent = btn
            
            starBtn.MouseButton1Click:Connect(function()
                if savedConfig.favs[anim.name] then
                    savedConfig.favs[anim.name] = nil
                    starBtn.Text = "☆"
                    starBtn.TextColor3 = C.textMuted
                else
                    savedConfig.favs[anim.name] = true
                    starBtn.Text = "★"
                    starBtn.TextColor3 = C.accent
                end
                saveConfig()
                if currentTab == "Favorites" then
                    populateList(searchBox.Text)
                end
            end)
            
            -- Keybind Button
            local bindBtn = Instance.new("TextButton")
            bindBtn.Size = UDim2.new(0, 80, 0, 24)
            bindBtn.Position = UDim2.new(1, -85, 0.5, -12)
            bindBtn.BackgroundColor3 = C.input
            local boundKey = savedConfig.binds[anim.name]
            bindBtn.Text = boundKey and ("[" .. boundKey .. "]") or "[...]"
            bindBtn.TextColor3 = boundKey and C.accent or C.textMuted
            bindBtn.TextSize = 11
            bindBtn.Font = Enum.Font.GothamSemibold
            bindBtn.Parent = btn
            applyCorner(bindBtn, 4)
            applyStroke(bindBtn, C.divider, 1, 0)
            
            bindBtn.MouseButton1Click:Connect(function()
                currentlyBinding = {name = anim.name, btn = bindBtn}
                bindBtn.Text = "[...]"
                bindBtn.TextColor3 = C.textMuted
            end)
            
            btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3 = C.surfaceHover}) end)
            btn.MouseLeave:Connect(function() tween(btn, {BackgroundColor3 = C.surface}) end)
            
            btn.MouseButton1Click:Connect(function()
                tween(btn, {BackgroundColor3 = C.accent, TextColor3 = C.bgCard}, 0.1)
                task.delay(0.15, function()
                    tween(btn, {BackgroundColor3 = C.surfaceHover, TextColor3 = C.text}, 0.2)
                end)
                
                toggleAnimation(anim.name, anim.path)
            end)
            
            table.insert(animButtons, btn)
        end
    end
    
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
end

searchBox.Changed:Connect(function(prop)
    if prop == "Text" then
        populateList(searchBox.Text)
    end
end)

tabAll.MouseButton1Click:Connect(function()
    currentTab = "All"
    tween(tabAll, {BackgroundColor3 = C.surfaceHover}, 0.2)
    tween(tabAllStroke, {Color = C.accent}, 0.2)
    tabAll.TextColor3 = C.text
    
    tween(tabFavs, {BackgroundColor3 = C.surface}, 0.2)
    tween(tabFavsStroke, {Color = C.divider}, 0.2)
    tabFavs.TextColor3 = C.textMuted
    
    populateList(searchBox.Text)
end)

tabFavs.MouseButton1Click:Connect(function()
    currentTab = "Favorites"
    tween(tabFavs, {BackgroundColor3 = C.surfaceHover}, 0.2)
    tween(tabFavsStroke, {Color = C.accent}, 0.2)
    tabFavs.TextColor3 = C.text
    
    tween(tabAll, {BackgroundColor3 = C.surface}, 0.2)
    tween(tabAllStroke, {Color = C.divider}, 0.2)
    tabAll.TextColor3 = C.textMuted
    
    populateList(searchBox.Text)
end)

populateList("")

-- Button Actions
toggleBtn.MouseEnter:Connect(function() tween(toggleBtn, {BackgroundColor3 = C.surfaceHover}) end)
toggleBtn.MouseLeave:Connect(function() tween(toggleBtn, {BackgroundColor3 = C.bgCard}) end)

toggleBtn.MouseButton1Click:Connect(function()
    toggleReanim()
end)


-- Global Keybind Handler
UserInputService.InputBegan:Connect(function(input, gp)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if currentlyBinding then
            local key = input.KeyCode.Name
            if key == "Escape" or key == "Backspace" then
                savedConfig.binds[currentlyBinding.name] = nil
                if currentlyBinding.btn and currentlyBinding.btn.Parent then
                    currentlyBinding.btn.Text = "[...]"
                    currentlyBinding.btn.TextColor3 = C.textMuted
                end
            else
                savedConfig.binds[currentlyBinding.name] = key
                if currentlyBinding.btn and currentlyBinding.btn.Parent then
                    currentlyBinding.btn.Text = "[" .. key .. "]"
                    currentlyBinding.btn.TextColor3 = C.accent
                end
            end
            saveConfig()
            currentlyBinding = nil
            return
        end
        
        if not gp then
            for animName, boundKey in pairs(savedConfig.binds) do
                if input.KeyCode.Name == boundKey then
                    local path = nil
                    for _, a in ipairs(animations) do
                        if a.name == animName then path = a.path break end
                    end
                    if path then
                        toggleAnimation(animName, path)
                    end
                end
            end
        end
    end
end)
