local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui", 5)
local HttpService = game:GetService("HttpService")

local API_URL = "https://yourscoper.vercel.app/api/nametag"
local SECRET = "yourscoper"

local taggedPlayers = {}
local dbCache = {}

local function fetchAllTags()
    local ok, result = pcall(function()
        return request({
            Url = API_URL .. "?secret=" .. SECRET,
            Method = "GET",
            Headers = { ["x-secret"] = SECRET }
        })
    end)
    if ok and result and result.Body then
        local ok2, data = pcall(function()
            return HttpService:JSONDecode(result.Body)
        end)
        if ok2 and data and data.nametags then
            return data.nametags
        end
    end
    return nil
end

local function AddTag(target, customTag)
    if not (target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")) then return end

    local existing = PlayerGui:FindFirstChild(target.Name .. "_ScopersTag")
    if existing then existing:Destroy() end

    local ScopersNameTag = Instance.new("BillboardGui")
    local NameTagMainFrame = Instance.new("Frame")
    local NameTagCustomName = Instance.new("TextLabel")
    local NameTagUserName = Instance.new("TextLabel")
    local NameTagMainFrameCorner = Instance.new("UICorner")
    local NameTagMainFrameStroke = Instance.new("UIStroke")
    local NameTagProfile = Instance.new("ImageLabel")
    local NameTagProfileCorner = Instance.new("UICorner")
    local NameTagMainFrameGradient = Instance.new("UIGradient")

    ScopersNameTag.Name = target.Name .. "_ScopersTag"
    ScopersNameTag.Active = true
    ScopersNameTag.AlwaysOnTop = true
    ScopersNameTag.ClipsDescendants = true
    ScopersNameTag.LightInfluence = 1
    ScopersNameTag.Size = UDim2.fromOffset(325, 100)
    ScopersNameTag.StudsOffset = Vector3.new(0, 4, 0)
    ScopersNameTag.ClipsDescendants = false
    ScopersNameTag.Adornee = target.Character:FindFirstChild("HumanoidRootPart")
    ScopersNameTag.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScopersNameTag.Parent = PlayerGui

    NameTagMainFrame.Name = "NameTagMainFrame"
    NameTagMainFrame.BackgroundColor3 = Color3.new(1, 1, 1)
    NameTagMainFrame.BackgroundTransparency = 0.25
    NameTagMainFrame.Size = UDim2.fromScale(1, 1)
    NameTagMainFrame.Parent = ScopersNameTag

    NameTagCustomName.Name = "NameTagCustomName"
    NameTagCustomName.BackgroundTransparency = 1
    NameTagCustomName.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
    NameTagCustomName.Position = UDim2.fromScale(0.29955, 0)
    NameTagCustomName.Size = UDim2.fromScale(0.7, 0.5)
    NameTagCustomName.Text = customTag
    NameTagCustomName.TextColor3 = Color3.new(1, 1, 1)
    NameTagCustomName.TextSize = 24
    NameTagCustomName.TextStrokeTransparency = 0
    NameTagCustomName.TextWrapped = true
    NameTagCustomName.TextXAlignment = Enum.TextXAlignment.Left
    NameTagCustomName.TextYAlignment = Enum.TextYAlignment.Bottom
    NameTagCustomName.Parent = NameTagMainFrame

    NameTagUserName.Name = "NameTagUserName"
    NameTagUserName.BackgroundTransparency = 1
    NameTagUserName.FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json")
    NameTagUserName.Position = UDim2.fromScale(0.29955, 0.5)
    NameTagUserName.Size = UDim2.fromScale(0.7, 0.5)
    NameTagUserName.Text = "@" .. target.Name
    NameTagUserName.TextColor3 = Color3.new(1, 1, 1)
    NameTagUserName.TextSize = 24
    NameTagUserName.TextStrokeTransparency = 0
    NameTagUserName.TextWrapped = true
    NameTagUserName.TextXAlignment = Enum.TextXAlignment.Left
    NameTagUserName.TextYAlignment = Enum.TextYAlignment.Top
    NameTagUserName.Parent = NameTagMainFrame

    NameTagMainFrameCorner.Name = "NameTagMainFrameCorner"
    NameTagMainFrameCorner.CornerRadius = UDim.new(0.4, 0)
    NameTagMainFrameCorner.Parent = NameTagMainFrame

    NameTagMainFrameStroke.Name = "NameTagMainFrameStroke"
    NameTagMainFrameStroke.ApplyStrokeMode = "Border"
    NameTagMainFrameStroke.Color = Color3.fromRGB(255, 255, 255)
    NameTagMainFrameStroke.Thickness = 4
    NameTagMainFrameStroke.Parent = NameTagMainFrame

    NameTagProfile.Name = "NameTagProfile"
    NameTagProfile.BackgroundTransparency = 1
    NameTagProfile.Image = "http://www.roblox.com/asset/?id=84826198167974"
    NameTagProfile.Position = UDim2.fromScale(0.0653153, 0.166667)
    NameTagProfile.Size = UDim2.fromScale(0.215, 0.7)
    NameTagProfile.Parent = NameTagMainFrame

    NameTagProfileCorner.Name = "NameTagProfileCorner"
    NameTagProfileCorner.CornerRadius = UDim.new(1, 0)
    NameTagProfileCorner.Parent = NameTagProfile

    NameTagMainFrameGradient.Name = "NameTagMainFrameGradient"
    NameTagMainFrameGradient.Parent = NameTagMainFrame
    NameTagMainFrameGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(75, 75, 75)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200)),
    })

    if target ~= Player then
        local NameTagMuteButton = Instance.new("ImageButton")
        local NameTagMuteButtonCorner = Instance.new("UICorner")
        local NameTagMuteButtonStroke = Instance.new("UIStroke")

        NameTagMuteButton.Name = "NameTagMuteButton"
        NameTagMuteButton.Parent = NameTagMainFrame
        NameTagMuteButton.BackgroundTransparency = 0
        NameTagMuteButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        NameTagMuteButton.BorderSizePixel = 0
        NameTagMuteButton.Image = "rbxasset://textures/ui/VoiceChat/MicLight/Unmuted0.png"
        NameTagMuteButton.Size = UDim2.new(0.15, 0, 0.5, 0)
        NameTagMuteButton.AutoButtonColor = false
        NameTagMuteButton.Position = UDim2.new(0.8, 0, 0.25, 0)

        NameTagMuteButtonCorner.Name = "NameTagMuteButtonCorner"
        NameTagMuteButtonCorner.CornerRadius = UDim.new(1, 0)
        NameTagMuteButtonCorner.Parent = NameTagMuteButton

        NameTagMuteButtonStroke.Name = "NameTagMuteButtonStroke"
        NameTagMuteButtonStroke.ApplyStrokeMode = "Border"
        NameTagMuteButtonStroke.Color = Color3.fromRGB(255, 255, 255)
        NameTagMuteButtonStroke.Thickness = 2
        NameTagMuteButtonStroke.Parent = NameTagMuteButton
    end
end

local function applyTagsFromCache()
    for _, target in next, Players:GetPlayers() do
        task.spawn(function()
            local userId = tostring(target.UserId)
            local entry = dbCache[userId]
            local tag = entry and entry.tag or nil

            if tag == nil then
                local existing = PlayerGui:FindFirstChild(target.Name .. "_ScopersTag")
                if existing then
                    existing:Destroy()
                    taggedPlayers[target.UserId] = nil
                end
                return
            end

            if taggedPlayers[target.UserId] == tag then return end

            if not target.Character then
                target.CharacterAdded:Wait()
            end

            AddTag(target, tag)
            taggedPlayers[target.UserId] = tag
        end)
    end
end

task.spawn(function()
    pcall(function()
        request({
            Url = API_URL .. "?secret=" .. SECRET,
            Method = "POST",
            Headers = {
                ["x-secret"] = SECRET,
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({
                userId      = tostring(Player.UserId),
                displayName = Player.DisplayName,
                tag         = "SCOPER USER"
            })
        })
    end)

    task.wait(1.5)

    local db = fetchAllTags()
    if db then
        dbCache = db
        applyTagsFromCache()
    end
end)

Players.PlayerAdded:Connect(function(target)
    task.wait(1)
    local userId = tostring(target.UserId)
    local entry = dbCache[userId]
    if entry and entry.tag then
        if not target.Character then
            target.CharacterAdded:Wait()
        end
        AddTag(target, entry.tag)
        taggedPlayers[target.UserId] = entry.tag
    end

    target.CharacterAdded:Connect(function()
        task.wait(0.5)
        if taggedPlayers[target.UserId] then
            AddTag(target, taggedPlayers[target.UserId])
        end
    end)
end)

Players.PlayerRemoving:Connect(function(target)
    pcall(function()
        request({
            Url = API_URL .. "?secret=" .. SECRET,
            Method = "DELETE",
            Headers = {
                ["x-secret"] = SECRET,
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({
                userId = tostring(target.UserId)
            })
        })
    end)
    taggedPlayers[target.UserId] = nil
    dbCache[tostring(target.UserId)] = nil
end)

task.spawn(function()
    while true do task.wait(5)
        local db = fetchAllTags()
        if db then
            dbCache = db
            applyTagsFromCache()
        end
    end
end)