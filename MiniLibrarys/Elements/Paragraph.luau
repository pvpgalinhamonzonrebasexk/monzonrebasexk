local env = getgenv and getgenv() or _G
local Library = env.MiniLibrary
local MiniElements = env.MiniElements

if type(Library) ~= "table" or type(MiniElements) ~= "table" then
    return
end

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Theme = Library.Theme
local Tweens = Library.Tweens
local tween = Library.Tween
local create = Library.Create
local addCorner = Library.AddCorner
local addStroke = Library.AddStroke
local createLabel = Library.CreateLabel
local resolveName = Library.ResolveName
local safeCall = Library.SafeCall
local report = Library.Report
local isPointerInput = Library.IsPointerInput

local PressedColor = Color3.fromRGB(96, 96, 105)
local HologramColor = Color3.fromRGB(0, 200, 255)
local LockedFade = 0.5
local DisabledFade = 0.6
local DefaultDuration = 0.15
local BaseZIndex = 50

local translateText = function(section, text)
    local window = section.Window
    if window and type(window.Translate) == "function" then
        return window:Translate(text)
    end
    return tostring(text or "")
end

local onLanguage = function(section, callback)
    local window = section.Window
    if window and type(window.OnLanguageChanged) == "function" then
        window:OnLanguageChanged(callback)
    end
end

local newSignal = function()
    local listeners = {}
    local signal = {}
    function signal:Connect(listener)
        if type(listener) ~= "function" then
            return nil
        end
        listeners[#listeners + 1] = listener
        return {
            Disconnect = function()
                local index = table.find(listeners, listener)
                if index then
                    table.remove(listeners, index)
                end
            end
        }
    end
    function signal:Fire(...)
        for _, listener in ipairs(table.clone(listeners)) do
            safeCall(listener, ...)
        end
    end
    function signal:Clear()
        table.clear(listeners)
    end
    return signal
end

local isTouchMode = function()
    local lastInput = UserInputService:GetLastInputType()
    if lastInput == Enum.UserInputType.Touch then
        return true
    end
    if lastInput == Enum.UserInputType.Keyboard or lastInput.Name:find("^Mouse") then
        return false
    end
    return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local measure = function(touch)
    if touch then
        return {
            Row = 46, Thumb = 64, HoloW = 72, HoloH = 94, HoloBanner = 200,
            Arrow = 34, Text = 13, Small = 11, Top = 44, Banner = 150
        }
    end
    return {
        Row = 40, Thumb = 56, HoloW = 64, HoloH = 84, HoloBanner = 180,
        Arrow = 28, Text = 12, Small = 10, Top = 36, Banner = 130
    }
end

local readDuration = function()
    local info = Tweens.Hover
    if typeof(info) == "TweenInfo" then
        return info.Time
    end
    return DefaultDuration
end

local resolveImage = function(value)
    if value == nil then
        return nil
    end
    if type(value) == "number" then
        return "rbxassetid://" .. tostring(math.floor(value))
    end
    local text = tostring(value)
    if text == "" then
        return nil
    end
    if text:match("^%d+$") then
        return "rbxassetid://" .. text
    end
    return text
end

local resolveStyle = function(value, hasImage, hasCharacter, hasPages)
    local text = string.lower(tostring(value or ""))
    if text == "name" then
        return "Name"
    end
    if text == "thumbnail" or text == "image" then
        return "Thumbnail"
    end
    if text == "hologram" or text == "holograma" then
        return "Hologram"
    end
    if text == "pages" or text == "page" or text == "carousel" then
        return "Pages"
    end
    if hasPages then
        return "Pages"
    end
    if hasCharacter then
        return "Hologram"
    end
    if hasImage then
        return "Thumbnail"
    end
    return "Name"
end

local normalizeBlock = function(raw)
    if type(raw) == "string" then
        return { Text = raw }
    end
    if type(raw) == "table" then
        return {
            Header = raw.Header ~= nil and tostring(raw.Header) or nil,
            Text = raw.Text ~= nil and tostring(raw.Text) or nil,
            Image = resolveImage(raw.Image),
            Height = tonumber(raw.Height)
        }
    end
    return nil
end

local normalizeContent = function(raw)
    local blocks = {}
    if raw == nil then
        return blocks
    end
    if type(raw) == "string" then
        blocks[1] = { Text = raw }
        return blocks
    end
    if type(raw) ~= "table" then
        return blocks
    end
    if raw[1] == nil and (raw.Text ~= nil or raw.Header ~= nil or raw.Image ~= nil) then
        local single = normalizeBlock(raw)
        if single then
            blocks[1] = single
        end
        return blocks
    end
    for _, item in ipairs(raw) do
        local block = normalizeBlock(item)
        if block then
            blocks[#blocks + 1] = block
        end
    end
    return blocks
end

local normalizePage = function(raw)
    if type(raw) == "string" then
        return { Title = nil, Text = raw, Image = nil }
    end
    if type(raw) == "table" then
        return {
            Title = (raw.Title or raw.Name or raw.Header) ~= nil and tostring(raw.Title or raw.Name or raw.Header) or nil,
            Text = raw.Text ~= nil and tostring(raw.Text) or nil,
            Image = resolveImage(raw.Image)
        }
    end
    return nil
end

local normalizePages = function(raw)
    local list = {}
    if type(raw) ~= "table" then
        return list
    end
    if raw[1] == nil and (raw.Text ~= nil or raw.Title ~= nil) then
        local single = normalizePage(raw)
        if single then
            list[1] = single
        end
        return list
    end
    for _, item in ipairs(raw) do
        local page = normalizePage(item)
        if page then
            list[#list + 1] = page
        end
    end
    return list
end

local findHost = function(start)
    local node = start.Parent
    while node do
        if node:IsA("GuiObject") or node:IsA("LayerCollector") then
            local free = true
            for _, child in ipairs(node:GetChildren()) do
                if child:IsA("UIGridStyleLayout") then
                    free = false
                    break
                end
            end
            if free then
                return node
            end
        end
        node = node.Parent
    end
    return nil
end

local buildChevron = function(parent, direction, color)
    local holder = create("Frame", {
        Size = UDim2.new(0, 12, 0, 12),
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, parent)
    local isLeft = direction == "Left"
    local shift = isLeft and 1 or -1
    local rotation = isLeft and -45 or 45
    local top = create("Frame", {
        Size = UDim2.new(0, 8, 0, 2),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, shift, 0.5, -3),
        Rotation = rotation,
        BackgroundColor3 = color,
        BorderSizePixel = 0
    }, holder)
    local bottom = create("Frame", {
        Size = UDim2.new(0, 8, 0, 2),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, shift, 0.5, 3),
        Rotation = -rotation,
        BackgroundColor3 = color,
        BorderSizePixel = 0
    }, holder)
    addCorner(top, 1)
    addCorner(bottom, 1)
    return holder, { top, bottom }
end

local setBars = function(bars, transparency)
    for _, bar in ipairs(bars) do
        bar.BackgroundTransparency = transparency
    end
end

local bindStates = function(button, base, hover, isDisabled)
    local hovering = false
    button.MouseEnter:Connect(function()
        hovering = true
        if isDisabled() then
            return
        end
        tween(button, Tweens.Hover, { BackgroundColor3 = hover })
    end)
    button.MouseLeave:Connect(function()
        hovering = false
        tween(button, Tweens.Hover, { BackgroundColor3 = base })
    end)
    button.InputBegan:Connect(function(input)
        if isDisabled() then
            return
        end
        if isPointerInput(input) then
            tween(button, Tweens.Hover, { BackgroundColor3 = PressedColor })
        end
    end)
    button.InputEnded:Connect(function(input)
        if isPointerInput(input) then
            local isTouch = input.UserInputType == Enum.UserInputType.Touch
            local active = hovering and not isTouch and not isDisabled()
            tween(button, Tweens.Hover, { BackgroundColor3 = active and hover or base })
        end
    end)
end

local waitCharacter = function(player)
    for _ = 1, 50 do
        if player.Character then
            return player.Character
        end
        task.wait(0.2)
    end
    return nil
end

local resolveCharacter
resolveCharacter = function(source, depth)
    depth = depth or 0
    if depth > 4 or source == nil then
        return nil
    end
    local kind = typeof(source)
    if kind == "function" then
        local ok, result = pcall(source)
        if not ok then
            report("Warning", "Paragraph", "Character callback error: " .. tostring(result))
            return nil
        end
        return resolveCharacter(result, depth + 1)
    end
    if kind == "boolean" then
        if source and Players.LocalPlayer then
            return waitCharacter(Players.LocalPlayer)
        end
        return nil
    end
    if kind == "Instance" then
        if source:IsA("Player") then
            return source.Character or waitCharacter(source)
        end
        if source:IsA("Humanoid") then
            return source.Parent
        end
        if source:IsA("Model") then
            return source
        end
        return nil
    end
    if kind == "number" then
        local ok, model = pcall(function()
            return Players:CreateHumanoidModelFromUserId(source)
        end)
        if ok then
            return model
        end
        return nil
    end
    if kind == "string" then
        local lowered = string.lower(source)
        if lowered == "localplayer" or lowered == "me" or lowered == "self" then
            if Players.LocalPlayer then
                return waitCharacter(Players.LocalPlayer)
            end
            return nil
        end
        local player = Players:FindFirstChild(source)
        if player and player:IsA("Player") then
            return player.Character or waitCharacter(player)
        end
        local okId, userId = pcall(function()
            return Players:GetUserIdFromNameAsync(source)
        end)
        if okId and userId then
            return resolveCharacter(userId, depth + 1)
        end
        return nil
    end
    return nil
end

local cloneCharacter = function(source)
    local original = source.Archivable
    if not original then
        pcall(function()
            source.Archivable = true
        end)
    end
    local ok, clone = pcall(function()
        return source:Clone()
    end)
    if not original then
        pcall(function()
            source.Archivable = false
        end)
    end
    if not ok or not clone then
        return nil
    end
    for _, item in ipairs(clone:GetDescendants()) do
        if item:IsA("LuaSourceContainer") or item:IsA("Sound") or item:IsA("BillboardGui") or item:IsA("ForceField") then
            item:Destroy()
        elseif item:IsA("BasePart") then
            item.Anchored = true
        elseif item:IsA("Humanoid") then
            pcall(function()
                item.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                item.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
            end)
        end
    end
    return clone
end

local buildHologram = function(parent, color, lineCount)
    local entry = { Offset = CFrame.new(), Model = nil, Lines = {}, Aspect = 0.76 }
    local root = create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ClipsDescendants = true
    }, parent)
    addCorner(root, 6)
    create("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(4, 12, 18), Color3.fromRGB(8, 34, 46)),
        Rotation = 90
    }, root)
    entry.Root = root
    entry.Stroke = addStroke(root, color, 1)
    entry.Stroke.Transparency = 0.4

    entry.Viewport = create("ViewportFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ImageColor3 = color:Lerp(Color3.fromRGB(255, 255, 255), 0.35),
        ImageTransparency = 0.12,
        Ambient = color:Lerp(Color3.fromRGB(255, 255, 255), 0.5),
        LightColor = Color3.fromRGB(255, 255, 255),
        LightDirection = Vector3.new(0.3, -0.5, 1)
    }, root)
    entry.Camera = Instance.new("Camera")
    entry.Camera.FieldOfView = 40
    entry.Camera.Parent = entry.Viewport
    entry.Viewport.CurrentCamera = entry.Camera

    entry.Base = create("Frame", {
        Size = UDim2.new(0.7, 0, 0, 5),
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -4),
        BackgroundColor3 = color,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0
    }, root)
    addCorner(entry.Base, 5)

    for index = 0, lineCount - 1 do
        local line = create("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, index / lineCount, 0),
            BackgroundColor3 = color,
            BackgroundTransparency = 0.88,
            BorderSizePixel = 0
        }, root)
        entry.Lines[#entry.Lines + 1] = line
    end

    entry.Sweep = create("Frame", {
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, -0.2, 0),
        BackgroundColor3 = color,
        BorderSizePixel = 0
    }, root)
    create("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.6),
            NumberSequenceKeypoint.new(1, 1)
        })
    }, entry.Sweep)

    return entry
end

local recolorHologram = function(entry, color)
    if not entry.Root.Parent then
        return
    end
    entry.Stroke.Color = color
    entry.Base.BackgroundColor3 = color
    entry.Sweep.BackgroundColor3 = color
    entry.Viewport.ImageColor3 = color:Lerp(Color3.fromRGB(255, 255, 255), 0.35)
    entry.Viewport.Ambient = color:Lerp(Color3.fromRGB(255, 255, 255), 0.5)
    for _, line in ipairs(entry.Lines) do
        line.BackgroundColor3 = color
    end
end

local placeModel = function(entry, source)
    if not entry.Root.Parent then
        return
    end
    if entry.Model then
        entry.Model:Destroy()
        entry.Model = nil
    end
    if not source then
        return
    end
    local model = cloneCharacter(source)
    if not model then
        return
    end
    model.Parent = entry.Viewport
    local pivot = model:GetPivot()
    local box, size = model:GetBoundingBox()
    local offset = pivot:ToObjectSpace(box)
    entry.Offset = offset:Inverse()
    model:PivotTo(entry.Offset)
    entry.Model = model
    local halfV = math.tan(math.rad(entry.Camera.FieldOfView / 2))
    local halfH = halfV * entry.Aspect
    local distance = math.max((size.Y / 2) / halfV, (size.X / 2) / halfH) * 1.12 + size.Z / 2
    entry.Camera.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.04, -distance), Vector3.new(0, 0, 0))
end

local constructParagraph = function(section, options)
    options = type(options) == "table" and options or {}
    local window = section.Window
    local touchMode = isTouchMode()
    local dims = measure(touchMode)
    local callback = options.Callback
    local locked = options.Locked == true
    local titleKey = resolveName(options)
    local descriptionKey = options.Description ~= nil and tostring(options.Description) or ""
    local pageTitleKey = options.PageTitle ~= nil and tostring(options.PageTitle) or nil
    local thumbImage = resolveImage(options.Image or options.Thumbnail)
    local pageImage = resolveImage(options.PageImage)
    local characterSource = options.Character
    if characterSource == nil then
        characterSource = options.Avatar
    end
    local holoColor = typeof(options.HologramColor) == "Color3" and options.HologramColor or HologramColor
    local rotate = options.Rotate ~= false
    local rotateSpeed = tonumber(options.RotateSpeed) or 0.9
    local pages = normalizePages(options.Pages)
    local loop = options.Loop == true
    local pageCallback = options.PageCallback or options.OnPage
    local pageIndex = math.clamp(math.floor(tonumber(options.PageIndex or options.StartPage) or 1), 1, math.max(1, #pages))
    local style = resolveStyle(options.Style or options.Mode, thumbImage ~= nil, characterSource ~= nil, #pages > 0)
    local blocks = normalizeContent(options.Content or options.Text)
    local opened = false
    local animationToken = 0
    local target = nil
    local host = nil
    local clipper = nil
    local page = nil
    local pageTitle = nil
    local backLabel = nil
    local body = nil
    local watchers = {}
    local holograms = {}
    local heartbeat = nil
    local angle = 0
    local sweepTime = 0
    local characterModel = nil
    local characterToken = 0
    local cardHolo = nil
    local dots = {}
    local openedSignal = newSignal()
    local closedSignal = newSignal()
    local pageSignal = newSignal()

    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, section.Frame)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0)
    }, row)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 4)
    }, row)

    local object = { Frame = row }

    local card = create("TextButton", {
        Size = UDim2.new(1, 0, 0, dims.Row),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = 1
    }, row)
    addCorner(card, 6)
    addStroke(card, Theme.Line, 1)
    create("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8)
    }, card)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        Padding = UDim.new(0, 10)
    }, card)

    local thumb = create("ImageLabel", {
        Size = UDim2.new(0, dims.Thumb, 0, dims.Thumb),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Image = "",
        ScaleType = Enum.ScaleType.Crop,
        Visible = false,
        LayoutOrder = 1
    }, card)
    addCorner(thumb, 6)
    addStroke(thumb, Theme.Line, 1)
    local thumbGradient = create("UIGradient", {
        Color = ColorSequence.new(Theme.Line, Theme.LineActive),
        Rotation = 45
    }, thumb)

    local textBlock = create("Frame", {
        Size = UDim2.new(1, -22, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 2
    }, card)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2)
    }, textBlock)

    local titleLabel = createLabel(textBlock, translateText(section, titleKey), 0)
    titleLabel.Size = UDim2.new(1, 0, 0, 16)
    titleLabel.LayoutOrder = 1

    local descriptionLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextSecondary,
        TextSize = dims.Small,
        Font = Enum.Font.Gotham,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Visible = false,
        LayoutOrder = 2
    }, textBlock)

    local arrow, arrowBars = buildChevron(card, "Right", Theme.TextSecondary)
    arrow.LayoutOrder = 3

    local pager = create("Frame", {
        Size = UDim2.new(1, 0, 0, dims.Row),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Visible = false,
        LayoutOrder = 2
    }, row)
    addCorner(pager, 6)
    addStroke(pager, Theme.Line, 1)
    create("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10)
    }, pager)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8)
    }, pager)

    local pagerHeader = create("Frame", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1
    }, pager)
    local pagerTitle = createLabel(pagerHeader, translateText(section, titleKey), 0)
    pagerTitle.Size = UDim2.new(1, -50, 1, 0)
    local pagerCounter = create("TextLabel", {
        Size = UDim2.new(0, 46, 1, 0),
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextSecondary,
        TextSize = dims.Small,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Right
    }, pagerHeader)

    local pagerDescription = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextSecondary,
        TextSize = dims.Small,
        Font = Enum.Font.Gotham,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Visible = false,
        LayoutOrder = 2
    }, pager)

    local pagerBody = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 3
    }, pager)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        Padding = UDim.new(0, 8)
    }, pagerBody)

    local prevButton = create("TextButton", {
        Size = UDim2.new(0, dims.Arrow, 0, dims.Arrow),
        BackgroundColor3 = Theme.Line,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = 1
    }, pagerBody)
    addCorner(prevButton, 6)
    local prevChevron, prevBars = buildChevron(prevButton, "Left", Theme.TextPrimary)
    prevChevron.AnchorPoint = Vector2.new(0.5, 0.5)
    prevChevron.Position = UDim2.new(0.5, 0, 0.5, 0)

    local pagerContent = create("Frame", {
        Size = UDim2.new(1, -(dims.Arrow * 2 + 16), 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 2
    }, pagerBody)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6)
    }, pagerContent)

    local pageImageLabel = create("ImageLabel", {
        Size = UDim2.new(1, 0, 0, math.floor(dims.Banner * 0.7)),
        BackgroundColor3 = Theme.Line,
        BorderSizePixel = 0,
        Image = "",
        ScaleType = Enum.ScaleType.Crop,
        Visible = false,
        LayoutOrder = 1
    }, pagerContent)
    addCorner(pageImageLabel, 6)

    local pageTitleLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextPrimary,
        TextSize = dims.Text + 1,
        Font = Enum.Font.GothamBold,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Visible = false,
        LayoutOrder = 2
    }, pagerContent)

    local pageTextLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextSecondary,
        TextSize = dims.Text,
        Font = Enum.Font.Gotham,
        RichText = true,
        TextWrapped = true,
        LineHeight = 1.15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Visible = false,
        LayoutOrder = 3
    }, pagerContent)

    local nextButton = create("TextButton", {
        Size = UDim2.new(0, dims.Arrow, 0, dims.Arrow),
        BackgroundColor3 = Theme.Line,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = 3
    }, pagerBody)
    addCorner(nextButton, 6)
    local nextChevron, nextBars = buildChevron(nextButton, "Right", Theme.TextPrimary)
    nextChevron.AnchorPoint = Vector2.new(0.5, 0.5)
    nextChevron.Position = UDim2.new(0.5, 0, 0.5, 0)

    local dotsFrame = create("Frame", {
        Size = UDim2.new(1, 0, 0, 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 4
    }, pager)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Padding = UDim.new(0, 5)
    }, dotsFrame)

    local canPrev = function()
        if locked or #pages < 2 then
            return false
        end
        return loop or pageIndex > 1
    end

    local canNext = function()
        if locked or #pages < 2 then
            return false
        end
        return loop or pageIndex < #pages
    end

    bindStates(card, Theme.Card, Theme.LineActive, function()
        return locked
    end)
    bindStates(prevButton, Theme.Line, Theme.LineActive, function()
        return not canPrev()
    end)
    bindStates(nextButton, Theme.Line, Theme.LineActive, function()
        return not canNext()
    end)

    local registerHologram
    local startHeartbeat

    startHeartbeat = function()
        if heartbeat then
            return
        end
        heartbeat = RunService.Heartbeat:Connect(function(delta)
            angle = angle + delta * rotateSpeed
            sweepTime = (sweepTime + delta * 0.5) % 1.4
            local alive = false
            for index = #holograms, 1, -1 do
                local entry = holograms[index]
                if not entry.Root.Parent then
                    table.remove(holograms, index)
                else
                    alive = true
                    entry.Sweep.Position = UDim2.new(0, 0, sweepTime - 0.2, 0)
                    if rotate and entry.Model then
                        entry.Model:PivotTo(CFrame.Angles(0, angle, 0) * entry.Offset)
                    end
                end
            end
            if not alive and heartbeat then
                heartbeat:Disconnect()
                heartbeat = nil
            end
        end)
    end

    registerHologram = function(entry)
        holograms[#holograms + 1] = entry
        startHeartbeat()
    end

    local refreshHolograms = function()
        for _, entry in ipairs(holograms) do
            placeModel(entry, characterModel)
        end
    end

    local loadCharacter = function()
        characterToken = characterToken + 1
        local token = characterToken
        if characterSource == nil then
            characterModel = nil
            refreshHolograms()
            return
        end
        task.spawn(function()
            local model = resolveCharacter(characterSource)
            if token ~= characterToken then
                return
            end
            if not model then
                report("Warning", "Paragraph", "Character not found")
            end
            characterModel = model
            refreshHolograms()
        end)
    end

    local ensureCardHologram = function()
        if cardHolo and cardHolo.Root.Parent then
            return cardHolo
        end
        cardHolo = buildHologram(card, holoColor, 14)
        cardHolo.Root.LayoutOrder = 1
        cardHolo.Root.Visible = false
        registerHologram(cardHolo)
        return cardHolo
    end

    local applyZIndex = function()
        if not clipper then
            return
        end
        clipper.ZIndex = BaseZIndex
        for _, item in ipairs(clipper:GetDescendants()) do
            if item:IsA("GuiObject") then
                local depth = 0
                local node = item
                while node and node ~= clipper do
                    depth = depth + 1
                    node = node.Parent
                end
                item.ZIndex = BaseZIndex + depth
            end
        end
    end

    local syncPage = function()
        if not clipper or not target or not host or not target.Parent then
            return
        end
        local hostSize = host.AbsoluteSize
        if hostSize.X <= 0 or hostSize.Y <= 0 then
            return
        end
        local hostPosition = host:IsA("GuiObject") and host.AbsolutePosition or Vector2.zero
        local relative = target.AbsolutePosition - hostPosition
        local size = target.AbsoluteSize
        clipper.Position = UDim2.fromScale(relative.X / hostSize.X, relative.Y / hostSize.Y)
        clipper.Size = UDim2.fromScale(size.X / hostSize.X, size.Y / hostSize.Y)
    end

    local buildContent = function()
        if not body then
            return
        end
        for _, child in ipairs(body:GetChildren()) do
            if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                child:Destroy()
            end
        end
        local order = 0
        local bannerImage = pageImage
        if bannerImage == nil and style == "Thumbnail" then
            bannerImage = thumbImage
        end
        if bannerImage then
            order = order + 1
            local banner = create("ImageLabel", {
                Size = UDim2.new(1, 0, 0, dims.Banner),
                BackgroundColor3 = Theme.Card,
                BorderSizePixel = 0,
                Image = bannerImage,
                ScaleType = Enum.ScaleType.Crop,
                LayoutOrder = order
            }, body)
            addCorner(banner, 8)
        elseif style == "Hologram" then
            order = order + 1
            local container = create("Frame", {
                Size = UDim2.new(1, 0, 0, dims.HoloBanner),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = order
            }, body)
            local entry = buildHologram(container, holoColor, 26)
            entry.Root.Size = UDim2.new(1, 0, 1, 0)
            local width = body.AbsoluteSize.X - 24
            entry.Aspect = width > 0 and width / dims.HoloBanner or 1.6
            registerHologram(entry)
            placeModel(entry, characterModel)
        end
        if descriptionKey ~= "" then
            order = order + 1
            create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Text = translateText(section, descriptionKey),
                TextColor3 = Theme.TextSecondary,
                TextSize = dims.Small + 1,
                Font = Enum.Font.GothamMedium,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                LayoutOrder = order
            }, body)
        end
        for _, block in ipairs(blocks) do
            if block.Image then
                order = order + 1
                local image = create("ImageLabel", {
                    Size = UDim2.new(1, 0, 0, block.Height or dims.Banner),
                    BackgroundColor3 = Theme.Card,
                    BorderSizePixel = 0,
                    Image = block.Image,
                    ScaleType = Enum.ScaleType.Crop,
                    LayoutOrder = order
                }, body)
                addCorner(image, 8)
            end
            if block.Header then
                order = order + 1
                create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Text = translateText(section, block.Header),
                    TextColor3 = Theme.TextPrimary,
                    TextSize = dims.Text + 2,
                    Font = Enum.Font.GothamBold,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    LayoutOrder = order
                }, body)
            end
            if block.Text then
                order = order + 1
                create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Text = translateText(section, block.Text),
                    TextColor3 = Theme.TextSecondary,
                    TextSize = dims.Text,
                    Font = Enum.Font.Gotham,
                    RichText = true,
                    TextWrapped = true,
                    LineHeight = 1.15,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    LayoutOrder = order
                }, body)
            end
        end
        applyZIndex()
    end

    local applyPageTexts = function()
        if not page then
            return
        end
        local key = pageTitleKey or titleKey
        pageTitle.Text = translateText(section, key)
        backLabel.Text = translateText(section, "Back")
    end

    local ensurePage = function()
        if page then
            return true
        end
        local scroll = row:FindFirstAncestorWhichIsA("ScrollingFrame")
        target = scroll or section.Frame
        host = findHost(target)
        if not host then
            return false
        end
        clipper = create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Visible = false,
            ZIndex = BaseZIndex
        }, host)
        page = create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Theme.Background or Theme.Card,
            BorderSizePixel = 0,
            Active = true
        }, clipper)

        local topbar = create("Frame", {
            Size = UDim2.new(1, 0, 0, dims.Top),
            BackgroundTransparency = 1,
            BorderSizePixel = 0
        }, page)

        pageTitle = create("TextLabel", {
            Size = UDim2.new(1, -176, 1, 0),
            Position = UDim2.new(0, 88, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            TextColor3 = Theme.TextPrimary,
            TextSize = dims.Text + 1,
            Font = Enum.Font.GothamBold,
            TextTruncate = Enum.TextTruncate.AtEnd
        }, topbar)

        local back = create("TextButton", {
            Size = UDim2.new(0, 80, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = ""
        }, topbar)
        create("UIPadding", {
            PaddingLeft = UDim.new(0, 12)
        }, back)
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 6)
        }, back)
        local backArrow = buildChevron(back, "Left", Theme.TextPrimary)
        backArrow.LayoutOrder = 1
        backLabel = create("TextLabel", {
            Size = UDim2.new(0, 40, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            TextColor3 = Theme.TextPrimary,
            TextSize = dims.Text,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 2
        }, back)

        create("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 0, dims.Top),
            BackgroundColor3 = Theme.Line,
            BorderSizePixel = 0
        }, page)

        body = create("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, -(dims.Top + 1)),
            Position = UDim2.new(0, 0, 0, dims.Top + 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollBarThickness = touchMode and 5 or 3,
            ScrollBarImageColor3 = Theme.LineActive
        }, page)
        create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 10)
        }, body)
        create("UIPadding", {
            PaddingTop = UDim.new(0, 12),
            PaddingBottom = UDim.new(0, 12),
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12)
        }, body)

        back.Activated:Connect(function()
            object:Close()
        end)

        applyPageTexts()
        buildContent()
        return true
    end

    local disconnectWatchers = function()
        for _, connection in ipairs(watchers) do
            connection:Disconnect()
        end
        table.clear(watchers)
    end

    local closePage
    local connectWatchers = function()
        disconnectWatchers()
        local node = row
        while node do
            if node:IsA("GuiObject") then
                local watched = node
                watchers[#watchers + 1] = watched:GetPropertyChangedSignal("Visible"):Connect(function()
                    if not watched.Visible then
                        closePage(true)
                    end
                end)
            end
            node = node.Parent
        end
        if target then
            watchers[#watchers + 1] = target:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncPage)
            watchers[#watchers + 1] = target:GetPropertyChangedSignal("AbsolutePosition"):Connect(syncPage)
        end
        if host then
            watchers[#watchers + 1] = host:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncPage)
        end
    end

    closePage = function(instant)
        if not opened then
            return
        end
        opened = false
        disconnectWatchers()
        animationToken = animationToken + 1
        local token = animationToken
        if instant == true then
            page.Position = UDim2.new(1, 0, 0, 0)
            clipper.Visible = false
        else
            tween(page, Tweens.Hover, { Position = UDim2.new(1, 0, 0, 0) })
            task.delay(readDuration() + 0.05, function()
                if token ~= animationToken or opened or not clipper then
                    return
                end
                clipper.Visible = false
            end)
        end
        closedSignal:Fire()
        safeCall(callback, false)
    end

    local openPage = function()
        if opened or locked or style == "Pages" then
            return
        end
        if not ensurePage() then
            report("Warning", "Paragraph", "No host found for the page")
            return
        end
        opened = true
        animationToken = animationToken + 1
        syncPage()
        applyPageTexts()
        buildContent()
        clipper.Visible = true
        page.Position = UDim2.new(1, 0, 0, 0)
        tween(page, Tweens.Hover, { Position = UDim2.new(0, 0, 0, 0) })
        connectWatchers()
        openedSignal:Fire()
        safeCall(callback, true)
    end

    local rebuildDots = function()
        for _, dot in ipairs(dots) do
            dot:Destroy()
        end
        table.clear(dots)
        for index = 1, #pages do
            local dot = create("TextButton", {
                Size = UDim2.new(0, 6, 0, 6),
                BackgroundColor3 = Theme.LineActive,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
                LayoutOrder = index
            }, dotsFrame)
            addCorner(dot, 6)
            dot.Activated:Connect(function()
                if locked then
                    return
                end
                object:SetPage(index, true)
            end)
            dots[index] = dot
        end
        dotsFrame.Visible = #pages > 1
    end

    local updateDots = function()
        for index, dot in ipairs(dots) do
            local active = index == pageIndex
            tween(dot, Tweens.Hover, {
                Size = UDim2.new(0, active and 16 or 6, 0, 6),
                BackgroundColor3 = active and Theme.TextPrimary or Theme.LineActive
            })
        end
    end

    local updateArrows = function()
        local prevOn = canPrev()
        local nextOn = canNext()
        prevButton.BackgroundTransparency = prevOn and 0 or DisabledFade
        nextButton.BackgroundTransparency = nextOn and 0 or DisabledFade
        setBars(prevBars, prevOn and 0 or DisabledFade)
        setBars(nextBars, nextOn and 0 or DisabledFade)
    end

    local renderPager = function(animate)
        local count = #pages
        local current = pages[pageIndex]
        pagerCounter.Text = count > 0 and (tostring(pageIndex) .. "/" .. tostring(count)) or ""
        local title = current and current.Title or nil
        local text = current and current.Text or nil
        local image = current and current.Image or nil
        pageTitleLabel.Text = title and translateText(section, title) or ""
        pageTitleLabel.Visible = title ~= nil and title ~= ""
        pageTextLabel.Text = text and translateText(section, text) or ""
        pageTextLabel.Visible = text ~= nil and text ~= ""
        pageImageLabel.Image = image or ""
        pageImageLabel.Visible = image ~= nil
        if animate then
            pageTitleLabel.TextTransparency = 1
            pageTextLabel.TextTransparency = 1
            pageImageLabel.ImageTransparency = 1
            tween(pageTitleLabel, Tweens.Hover, { TextTransparency = 0 })
            tween(pageTextLabel, Tweens.Hover, { TextTransparency = 0 })
            tween(pageImageLabel, Tweens.Hover, { ImageTransparency = 0 })
        end
        updateDots()
        updateArrows()
    end

    local setPageIndex = function(index, fire)
        local count = #pages
        if count == 0 then
            return
        end
        local clamped = math.clamp(math.floor(tonumber(index) or 1), 1, count)
        if clamped == pageIndex then
            return
        end
        pageIndex = clamped
        renderPager(true)
        if fire then
            pageSignal:Fire(pageIndex, pages[pageIndex])
            safeCall(pageCallback, pageIndex, pages[pageIndex])
        end
    end

    local stepPage = function(delta)
        local count = #pages
        if count < 2 or locked then
            return
        end
        local nextIndex = pageIndex + delta
        if nextIndex < 1 then
            if not loop then
                return
            end
            nextIndex = count
        elseif nextIndex > count then
            if not loop then
                return
            end
            nextIndex = 1
        end
        setPageIndex(nextIndex, true)
    end

    local applyCard = function()
        local isPages = style == "Pages"
        local hasThumb = style == "Thumbnail"
        local hasHolo = style == "Hologram"
        card.Visible = not isPages
        pager.Visible = isPages
        thumb.Visible = hasThumb
        thumb.Size = UDim2.new(0, dims.Thumb, 0, dims.Thumb)
        thumb.Image = thumbImage or ""
        thumb.ImageTransparency = thumbImage and 0 or 1
        thumb.BackgroundTransparency = thumbImage and 1 or 0
        thumbGradient.Enabled = thumbImage == nil
        if hasHolo then
            local entry = ensureCardHologram()
            entry.Root.Visible = true
            entry.Root.Size = UDim2.new(0, dims.HoloW, 0, dims.HoloH)
            entry.Aspect = dims.HoloW / dims.HoloH
            if characterModel and not entry.Model then
                placeModel(entry, characterModel)
            end
        elseif cardHolo and cardHolo.Root.Parent then
            cardHolo.Root.Visible = false
        end
        local visualWidth = hasThumb and dims.Thumb or (hasHolo and dims.HoloW or 0)
        local visualHeight = hasThumb and dims.Thumb or (hasHolo and dims.HoloH or 0)
        local hasVisual = hasThumb or hasHolo
        card.Size = UDim2.new(1, 0, 0, hasVisual and (visualHeight + 16) or dims.Row)
        textBlock.Size = UDim2.new(1, -(visualWidth + 12 + (hasVisual and 20 or 10)), 0, 0)
        descriptionLabel.TextSize = dims.Small
        prevButton.Size = UDim2.new(0, dims.Arrow, 0, dims.Arrow)
        nextButton.Size = UDim2.new(0, dims.Arrow, 0, dims.Arrow)
        pagerContent.Size = UDim2.new(1, -(dims.Arrow * 2 + 16), 0, 0)
        pageImageLabel.Size = UDim2.new(1, 0, 0, math.floor(dims.Banner * 0.7))
        pageTitleLabel.TextSize = dims.Text + 1
        pageTextLabel.TextSize = dims.Text
        pagerCounter.TextSize = dims.Small
        pagerDescription.TextSize = dims.Small
    end

    local applyTexts = function()
        local title = titleKey == "" and "" or translateText(section, titleKey)
        local description = descriptionKey == "" and "" or translateText(section, descriptionKey)
        titleLabel.Text = title
        titleLabel.Visible = title ~= ""
        descriptionLabel.Text = description
        descriptionLabel.Visible = description ~= ""
        pagerTitle.Text = title
        pagerHeader.Visible = title ~= "" or #pages > 0
        pagerDescription.Text = description
        pagerDescription.Visible = description ~= ""
        applyPageTexts()
        renderPager(false)
    end

    local applyLock = function()
        local fade = locked and LockedFade or 0
        card.BackgroundTransparency = fade
        pager.BackgroundTransparency = fade
        titleLabel.TextTransparency = fade
        descriptionLabel.TextTransparency = fade
        pagerTitle.TextTransparency = fade
        pagerDescription.TextTransparency = fade
        thumb.ImageTransparency = thumbImage and fade or 1
        setBars(arrowBars, fade)
        updateArrows()
        if locked then
            closePage(true)
        end
    end

    local applyLayout = function()
        touchMode = isTouchMode()
        dims = measure(touchMode)
        applyCard()
        if page then
            body.ScrollBarThickness = touchMode and 5 or 3
            buildContent()
        end
    end

    section:Connect(card.Activated, function()
        if locked then
            return
        end
        if opened then
            closePage(false)
        else
            openPage()
        end
    end)

    section:Connect(prevButton.Activated, function()
        stepPage(-1)
    end)

    section:Connect(nextButton.Activated, function()
        stepPage(1)
    end)

    section:Connect(UserInputService.InputBegan, function(input)
        if opened and input.KeyCode == Enum.KeyCode.Escape then
            closePage(false)
        end
    end)

    section:Connect(UserInputService.LastInputTypeChanged, function()
        if isTouchMode() ~= touchMode then
            applyLayout()
        end
    end)

    function object:Open()
        openPage()
    end

    function object:Close()
        closePage(false)
    end

    function object:ToggleOpen()
        if opened then
            closePage(false)
        else
            openPage()
        end
    end

    function object:IsOpen()
        return opened
    end

    function object:SetName(text)
        titleKey = tostring(text or "")
        applyTexts()
    end

    function object:GetName()
        return titleKey
    end

    function object:SetDescription(text)
        descriptionKey = tostring(text or "")
        applyTexts()
        buildContent()
    end

    function object:GetDescription()
        return descriptionKey
    end

    function object:SetPageTitle(text)
        pageTitleKey = text ~= nil and tostring(text) or nil
        applyPageTexts()
    end

    function object:SetStyle(value)
        style = resolveStyle(value, thumbImage ~= nil, characterSource ~= nil, #pages > 0)
        applyCard()
        applyTexts()
        buildContent()
    end

    function object:GetStyle()
        return style
    end

    function object:SetImage(value)
        thumbImage = resolveImage(value)
        applyCard()
        applyLock()
        buildContent()
    end

    function object:SetPageImage(value)
        pageImage = resolveImage(value)
        buildContent()
    end

    function object:SetContent(value)
        blocks = normalizeContent(value)
        buildContent()
    end

    function object:AddParagraph(text)
        blocks[#blocks + 1] = { Text = tostring(text or "") }
        buildContent()
    end

    function object:AddSection(header, text, image)
        blocks[#blocks + 1] = {
            Header = header ~= nil and tostring(header) or nil,
            Text = text ~= nil and tostring(text) or nil,
            Image = resolveImage(image)
        }
        buildContent()
    end

    function object:ClearContent()
        table.clear(blocks)
        buildContent()
    end

    function object:SetCharacter(source)
        characterSource = source
        if source ~= nil and options.Style == nil and style ~= "Pages" then
            style = "Hologram"
        end
        applyCard()
        loadCharacter()
        buildContent()
    end

    function object:RefreshCharacter()
        loadCharacter()
    end

    function object:GetCharacter()
        return characterModel
    end

    function object:SetHologramColor(color)
        if typeof(color) ~= "Color3" then
            report("Warning", "Paragraph", "SetHologramColor expects a Color3")
            return
        end
        holoColor = color
        for _, entry in ipairs(holograms) do
            recolorHologram(entry, holoColor)
        end
    end

    function object:SetRotate(state)
        rotate = state == true
    end

    function object:SetRotateSpeed(value)
        rotateSpeed = tonumber(value) or rotateSpeed
    end

    function object:SetPages(list)
        pages = normalizePages(list)
        pageIndex = math.clamp(pageIndex, 1, math.max(1, #pages))
        rebuildDots()
        renderPager(false)
        applyTexts()
    end

    function object:AddPage(value, index)
        local normalized = normalizePage(value)
        if not normalized then
            report("Warning", "Paragraph", "Invalid page")
            return false
        end
        local position = math.clamp(tonumber(index) or (#pages + 1), 1, #pages + 1)
        table.insert(pages, position, normalized)
        rebuildDots()
        renderPager(false)
        applyTexts()
        return true
    end

    function object:RemovePage(index)
        local position = tonumber(index)
        if not position or not pages[position] then
            return false
        end
        table.remove(pages, position)
        pageIndex = math.clamp(pageIndex, 1, math.max(1, #pages))
        rebuildDots()
        renderPager(false)
        applyTexts()
        return true
    end

    function object:ClearPages()
        table.clear(pages)
        pageIndex = 1
        rebuildDots()
        renderPager(false)
        applyTexts()
    end

    function object:SetPage(index, fire)
        setPageIndex(index, fire == true)
    end

    function object:NextPage()
        stepPage(1)
    end

    function object:PreviousPage()
        stepPage(-1)
    end

    function object:GetPage()
        return pageIndex
    end

    function object:GetPages()
        return pages
    end

    function object:GetPageCount()
        return #pages
    end

    function object:SetLoop(state)
        loop = state == true
        updateArrows()
    end

    function object:SetCallback(newCallback)
        if type(newCallback) == "function" then
            callback = newCallback
        end
    end

    function object:SetPageCallback(newCallback)
        if type(newCallback) == "function" then
            pageCallback = newCallback
        end
    end

    function object:OnOpened(listener)
        return openedSignal:Connect(listener)
    end

    function object:OnClosed(listener)
        return closedSignal:Connect(listener)
    end

    function object:OnPageChanged(listener)
        return pageSignal:Connect(listener)
    end

    function object:SetLocked(state)
        locked = state == true
        applyLock()
    end

    function object:IsLocked()
        return locked
    end

    function object:SetVisible(state)
        row.Visible = state == true
        if not row.Visible then
            closePage(true)
        end
    end

    function object:Update(values)
        if type(values) ~= "table" then
            report("Warning", "Paragraph", "Update needs a table")
            return false
        end
        local newName = values.Name or values.Title
        if newName ~= nil then
            titleKey = tostring(newName)
        end
        if values.Description ~= nil then
            descriptionKey = tostring(values.Description)
        end
        if values.PageTitle ~= nil then
            pageTitleKey = tostring(values.PageTitle)
        end
        if type(values.Callback) == "function" then
            callback = values.Callback
        end
        if type(values.PageCallback) == "function" then
            pageCallback = values.PageCallback
        end
        local newImage = values.Image
        if newImage == nil then
            newImage = values.Thumbnail
        end
        if newImage ~= nil then
            thumbImage = resolveImage(newImage)
        end
        if values.PageImage ~= nil then
            pageImage = resolveImage(values.PageImage)
        end
        local newContent = values.Content
        if newContent == nil then
            newContent = values.Text
        end
        if newContent ~= nil then
            blocks = normalizeContent(newContent)
        end
        if values.Pages ~= nil then
            pages = normalizePages(values.Pages)
            pageIndex = math.clamp(pageIndex, 1, math.max(1, #pages))
            rebuildDots()
        end
        if values.PageIndex ~= nil and #pages > 0 then
            pageIndex = math.clamp(math.floor(tonumber(values.PageIndex) or 1), 1, #pages)
        end
        if values.Loop ~= nil then
            loop = values.Loop == true
        end
        if values.HologramColor ~= nil and typeof(values.HologramColor) == "Color3" then
            holoColor = values.HologramColor
            for _, entry in ipairs(holograms) do
                recolorHologram(entry, holoColor)
            end
        end
        if values.Rotate ~= nil then
            rotate = values.Rotate == true
        end
        if values.RotateSpeed ~= nil then
            rotateSpeed = tonumber(values.RotateSpeed) or rotateSpeed
        end
        local characterChanged = false
        if values.Character ~= nil then
            characterSource = values.Character
            characterChanged = true
        end
        local newStyle = values.Style or values.Mode
        if newStyle ~= nil then
            style = resolveStyle(newStyle, thumbImage ~= nil, characterSource ~= nil, #pages > 0)
        end
        if values.Locked ~= nil then
            locked = values.Locked == true
        end
        if values.Visible ~= nil then
            object:SetVisible(values.Visible)
        end
        applyCard()
        applyTexts()
        applyLock()
        buildContent()
        if characterChanged then
            loadCharacter()
        end
        return true
    end

    function object:Refresh()
        applyLayout()
        applyTexts()
        applyLock()
    end

    function object:Destroy()
        closePage(true)
        disconnectWatchers()
        characterToken = characterToken + 1
        if heartbeat then
            heartbeat:Disconnect()
            heartbeat = nil
        end
        table.clear(holograms)
        openedSignal:Clear()
        closedSignal:Clear()
        pageSignal:Clear()
        if clipper then
            clipper:Destroy()
        end
        row:Destroy()
    end

    rebuildDots()
    object:Refresh()
    loadCharacter()
    onLanguage(section, function()
        applyTexts()
        buildContent()
    end)

    return object
end

MiniElements.Register("Paragraph", function(section, options)
    local ok, result = pcall(constructParagraph, section, options)
    if not ok then
        warn("[Paragraph] " .. tostring(result))
        error(result, 0)
    end
    return result
end)