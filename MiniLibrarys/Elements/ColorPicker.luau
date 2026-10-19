local env = getgenv and getgenv() or _G
local Library = env.MiniLibrary
local MiniElements = env.MiniElements

if type(Library) ~= "table" or type(MiniElements) ~= "table" then
    return
end

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Theme = Library.Theme
local Tweens = Library.Tweens
local tween = Library.Tween
local cancelTween = Library.CancelTween
local create = Library.Create
local addCorner = Library.AddCorner
local addStroke = Library.AddStroke
local createLabel = Library.CreateLabel
local resolveName = Library.ResolveName
local safeCall = Library.SafeCall
local report = Library.Report
local isPointerInput = Library.IsPointerInput

local LockedFade = 0.5
local DefaultDuration = 0.15
local PanelPadding = 12
local PanelGap = 4
local SectionGap = 12
local CheckerImage = "rbxasset://textures/Checkerboard.png"
local MapImage = "rbxassetid://4155801252"
local DefaultColor = Color3.fromRGB(68, 120, 255)
local DarkText = Color3.fromRGB(20, 20, 20)
local LightText = Color3.fromRGB(255, 255, 255)

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
        return { Field = 38, FieldWidth = 104, Map = 150, Bar = 22, Hex = 38, Text = 13, Cursor = 20 }
    end
    return { Field = 32, FieldWidth = 96, Map = 130, Bar = 16, Hex = 30, Text = 12, Cursor = 16 }
end

local readDuration = function()
    local info = Tweens.Hover
    if typeof(info) == "TweenInfo" then
        return info.Time
    end
    return DefaultDuration
end

local pointInside = function(gui, position)
    local origin = gui.AbsolutePosition
    local size = gui.AbsoluteSize
    local inset = GuiService:GetGuiInset()
    local candidates = { position, position + Vector2.new(0, inset.Y) }
    for _, point in ipairs(candidates) do
        local insideX = point.X >= origin.X and point.X <= origin.X + size.X
        local insideY = point.Y >= origin.Y and point.Y <= origin.Y + size.Y
        if insideX and insideY then
            return true
        end
    end
    return false
end

local toHex = function(color)
    return string.format(
        "%02X%02X%02X",
        math.round(color.R * 255),
        math.round(color.G * 255),
        math.round(color.B * 255)
    )
end

local parseHex = function(text)
    local clean = (tostring(text or ""):gsub("[#%s]", ""))
    if #clean == 3 then
        clean = clean:gsub(".", function(char)
            return char .. char
        end)
    end
    if #clean ~= 6 or clean:find("%X") then
        return nil
    end
    local r = tonumber(clean:sub(1, 2), 16)
    local g = tonumber(clean:sub(3, 4), 16)
    local b = tonumber(clean:sub(5, 6), 16)
    if not (r and g and b) then
        return nil
    end
    return Color3.fromRGB(r, g, b)
end

local contrastColor = function(color, transparency)
    local background = 0.12
    local r = color.R * (1 - transparency) + background * transparency
    local g = color.G * (1 - transparency) + background * transparency
    local b = color.B * (1 - transparency) + background * transparency
    local luminance = 0.299 * r + 0.587 * g + 0.114 * b
    return luminance > 0.55 and DarkText or LightText
end

local constructColorPicker = function(section, options)
    options = type(options) == "table" and options or {}
    local window = section.Window
    local touchMode = isTouchMode()
    local dims = measure(touchMode)
    local callback = options.Callback
    local locked = options.Locked == true
    local allowAlpha = options.AllowAlpha ~= false
    local opened = false
    local titleKey = resolveName(options)
    local descriptionKey = options.Description ~= nil and tostring(options.Description) or ""
    local startColor = options.Default
    if startColor == nil then
        startColor = options.Value
    end
    if startColor == nil then
        startColor = options.Color
    end
    if typeof(startColor) ~= "Color3" then
        startColor = DefaultColor
    end
    local transparency = allowAlpha and math.clamp(tonumber(options.Transparency) or 0, 0, 1) or 0
    local current = startColor
    local hue, sat, vib = Color3.toHSV(startColor)
    local dragging = nil
    local openedAt = 0
    local dragEndedAt = 0
    local animationToken = 0
    local scrollLocks = {}
    local changedSignal = newSignal()
    local openedSignal = newSignal()
    local closedSignal = newSignal()

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
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6)
    }, row)

    local object = { Frame = row }

    local top = create("Frame", {
        Size = UDim2.new(1, 0, 0, dims.Field),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1
    }, row)

    local textBlock = create("Frame", {
        Size = UDim2.new(1, -(dims.FieldWidth + 10), 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, top)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2)
    }, textBlock)
    local textPadding = create("UIPadding", {}, textBlock)

    local titleLabel = createLabel(textBlock, translateText(section, titleKey), 0)
    titleLabel.Size = UDim2.new(1, 0, 0, 16)
    titleLabel.LayoutOrder = 1

    local descriptionLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextSecondary,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Visible = false,
        LayoutOrder = 2
    }, textBlock)

    local field = create("TextButton", {
        Size = UDim2.new(0, dims.FieldWidth, 0, dims.Field),
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = ""
    }, top)
    addCorner(field, 6)
    local fieldStroke = addStroke(field, Theme.Line, 1)

    local fieldChecker = create("ImageLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Image = CheckerImage,
        ImageTransparency = 0.45,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(8, 8)
    }, field)
    addCorner(fieldChecker, 6)

    local fieldColor = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = current,
        BorderSizePixel = 0
    }, field)
    addCorner(fieldColor, 6)

    local fieldLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = toHex(current),
        TextColor3 = LightText,
        TextSize = dims.Text,
        Font = Enum.Font.GothamBold
    }, fieldColor)

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        LayoutOrder = 2
    }, row)

    local panel = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, PanelGap),
        BackgroundColor3 = Theme.Card,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true
    }, holder)
    addCorner(panel, 6)
    local panelStroke = addStroke(panel, Theme.Line, 1)
    panelStroke.Transparency = 1
    create("UIPadding", {
        PaddingTop = UDim.new(0, PanelPadding),
        PaddingBottom = UDim.new(0, PanelPadding),
        PaddingLeft = UDim.new(0, PanelPadding),
        PaddingRight = UDim.new(0, PanelPadding)
    }, panel)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, SectionGap)
    }, panel)

    local satMap = create("ImageLabel", {
        Size = UDim2.new(1, 0, 0, dims.Map),
        Image = MapImage,
        BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
        BorderSizePixel = 0,
        LayoutOrder = 1
    }, panel)
    addCorner(satMap, 6)
    addStroke(satMap, Theme.Line, 1)

    local satCursor = create("Frame", {
        Size = UDim2.fromOffset(dims.Cursor, dims.Cursor),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(sat, 0, 1 - vib, 0),
        BackgroundColor3 = current,
        BorderSizePixel = 0
    }, satMap)
    addCorner(satCursor, dims.Cursor)
    addStroke(satCursor, Color3.fromRGB(255, 255, 255), 2)

    local hueSlider = create("Frame", {
        Size = UDim2.new(1, 0, 0, dims.Bar),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        LayoutOrder = 2
    }, panel)
    addCorner(hueSlider, 6)
    addStroke(hueSlider, Theme.Line, 1)

    local hueSequence = {}
    for index = 0, 10 do
        local step = index / 10
        hueSequence[#hueSequence + 1] = ColorSequenceKeypoint.new(step, Color3.fromHSV(math.min(step, 0.999), 1, 1))
    end
    create("UIGradient", {
        Color = ColorSequence.new(hueSequence)
    }, hueSlider)

    local hueCursor = create("Frame", {
        Size = UDim2.new(0, 4, 1, 6),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(hue, 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0
    }, hueSlider)
    addCorner(hueCursor, 2)
    addStroke(hueCursor, Color3.fromRGB(0, 0, 0), 1).Transparency = 0.4

    local alphaSlider = create("Frame", {
        Size = UDim2.new(1, 0, 0, dims.Bar),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Visible = allowAlpha,
        LayoutOrder = 3
    }, panel)
    addCorner(alphaSlider, 6)
    addStroke(alphaSlider, Theme.Line, 1)

    local alphaChecker = create("ImageLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Image = CheckerImage,
        ImageTransparency = 0.45,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(8, 8)
    }, alphaSlider)
    addCorner(alphaChecker, 6)

    local alphaFill = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0
    }, alphaSlider)
    addCorner(alphaFill, 6)
    local alphaGradient = create("UIGradient", {
        Color = ColorSequence.new(current),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1)
        })
    }, alphaFill)

    local alphaCursor = create("Frame", {
        Size = UDim2.new(0, 4, 1, 6),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(transparency, 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0
    }, alphaSlider)
    addCorner(alphaCursor, 2)
    addStroke(alphaCursor, Color3.fromRGB(0, 0, 0), 1).Transparency = 0.4

    local hexBox = create("TextBox", {
        Size = UDim2.new(1, 0, 0, dims.Hex),
        BackgroundColor3 = Theme.LineActive,
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        Text = toHex(current),
        PlaceholderText = "HEX",
        PlaceholderColor3 = Theme.TextSecondary,
        TextColor3 = Theme.TextPrimary,
        TextSize = dims.Text,
        Font = Enum.Font.GothamBold,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = 4
    }, panel)
    addCorner(hexBox, 6)
    local hexStroke = addStroke(hexBox, Theme.Line, 1)

    local hovering = false

    local pointerShift = { Mouse = nil, Touch = nil }

    local inputClass = function(input)
        return input.UserInputType == Enum.UserInputType.Touch and "Touch" or "Mouse"
    end

    local defaultShift = function()
        local screenGui = row:FindFirstAncestorWhichIsA("ScreenGui")
        if screenGui and screenGui.IgnoreGuiInset then
            return GuiService:GetGuiInset().Y
        end
        return 0
    end

    local calibrate = function(gui, input)
        local origin = gui.AbsolutePosition
        local size = gui.AbsoluteSize
        local rawX = input.Position.X
        local rawY = input.Position.Y
        if rawX < origin.X or rawX > origin.X + size.X then
            return
        end
        local insetY = GuiService:GetGuiInset().Y
        local shifts = { 0, insetY, -insetY, 36, -36, 58, -58 }
        local centerY = origin.Y + size.Y / 2
        local best = nil
        local bestScore = nil
        for _, shift in ipairs(shifts) do
            local y = rawY + shift
            if y >= origin.Y and y <= origin.Y + size.Y then
                local score = math.abs(y - centerY) + math.abs(shift) * 0.001
                if not bestScore or score < bestScore then
                    best = shift
                    bestScore = score
                end
            end
        end
        if best ~= nil then
            pointerShift[inputClass(input)] = best
        end
    end

    local toGuiPosition = function(input)
        local class = inputClass(input)
        local shift = pointerShift[class]
        if shift == nil then
            shift = defaultShift()
        end
        return Vector2.new(input.Position.X, input.Position.Y + shift)
    end

    local lockScroll = function()
        if #scrollLocks > 0 then
            return
        end
        local parent = row.Parent
        while parent do
            if parent:IsA("ScrollingFrame") and parent.ScrollingEnabled then
                scrollLocks[#scrollLocks + 1] = parent
                parent.ScrollingEnabled = false
            end
            parent = parent.Parent
        end
    end

    local unlockScroll = function()
        for _, frame in ipairs(scrollLocks) do
            if frame.Parent then
                frame.ScrollingEnabled = true
            end
        end
        table.clear(scrollLocks)
    end

    local targetHeight = function()
        local count = allowAlpha and 4 or 3
        local total = PanelPadding * 2 + dims.Map + dims.Bar + dims.Hex + (count - 1) * SectionGap
        if allowAlpha then
            total = total + dims.Bar
        end
        return total
    end

    local updateHeight = function(instant)
        if not opened then
            return
        end
        local height = targetHeight()
        local panelGoal = UDim2.new(1, 0, 0, height)
        local holderGoal = UDim2.new(1, 0, 0, height + PanelGap)
        if instant then
            cancelTween(panel)
            cancelTween(holder)
            panel.Size = panelGoal
            holder.Size = holderGoal
            return
        end
        tween(panel, Tweens.Hover, { Size = panelGoal })
        tween(holder, Tweens.Hover, { Size = holderGoal })
    end

    local render = function()
        satMap.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
        satCursor.Position = UDim2.new(sat, 0, 1 - vib, 0)
        satCursor.BackgroundColor3 = current
        hueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
        alphaCursor.Position = UDim2.new(transparency, 0, 0.5, 0)
        alphaGradient.Color = ColorSequence.new(current)
        local shown = locked and math.clamp(transparency + 0.4, 0, 1) or transparency
        fieldColor.BackgroundColor3 = current
        fieldColor.BackgroundTransparency = shown
        fieldLabel.Text = toHex(current)
        fieldLabel.TextColor3 = contrastColor(current, transparency)
        fieldLabel.TextTransparency = locked and LockedFade or 0
        if not hexBox:IsFocused() then
            hexBox.Text = toHex(current)
        end
    end

    local fireChange = function()
        safeCall(callback, current, transparency)
        changedSignal:Fire(current, transparency)
    end

    local updateFromInput = function(kind, input)
        local point = toGuiPosition(input)
        if kind == "map" then
            local origin = satMap.AbsolutePosition
            local size = satMap.AbsoluteSize
            if size.X > 0 then
                sat = math.clamp((point.X - origin.X) / size.X, 0, 1)
            end
            if size.Y > 0 then
                vib = 1 - math.clamp((point.Y - origin.Y) / size.Y, 0, 1)
            end
        elseif kind == "hue" then
            local origin = hueSlider.AbsolutePosition
            local size = hueSlider.AbsoluteSize
            if size.X > 0 then
                hue = math.clamp((point.X - origin.X) / size.X, 0, 1)
            end
        elseif kind == "alpha" then
            local origin = alphaSlider.AbsolutePosition
            local size = alphaSlider.AbsoluteSize
            if size.X > 0 then
                transparency = math.clamp((point.X - origin.X) / size.X, 0, 1)
            end
        end
        current = Color3.fromHSV(hue, sat, vib)
        render()
        fireChange()
    end

    local bindDrag = function(gui, kind)
        gui.InputBegan:Connect(function(input)
            if locked or not isPointerInput(input) then
                return
            end
            if kind ~= "map" then
                calibrate(gui, input)
            end
            dragging = kind
            lockScroll()
            updateFromInput(kind, input)
        end)
    end

    bindDrag(satMap, "map")
    bindDrag(hueSlider, "hue")
    bindDrag(alphaSlider, "alpha")

    section:Connect(UserInputService.InputChanged, function(input)
        if not dragging then
            return
        end
        local inputType = input.UserInputType
        if inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Touch then
            updateFromInput(dragging, input)
        end
    end)

    section:Connect(UserInputService.InputEnded, function(input)
        if dragging and isPointerInput(input) then
            dragging = nil
            dragEndedAt = os.clock()
            unlockScroll()
        end
    end)

    hexBox.Focused:Connect(function()
        tween(hexStroke, Tweens.Hover, { Color = Theme.LineActive })
    end)

    hexBox.FocusLost:Connect(function()
        tween(hexStroke, Tweens.Hover, { Color = Theme.Line })
        local parsed = parseHex(hexBox.Text)
        if parsed and not locked then
            current = parsed
            hue, sat, vib = Color3.toHSV(parsed)
            render()
            fireChange()
        else
            hexBox.Text = toHex(current)
        end
    end)

    local close = function()
        if not opened then
            return
        end
        opened = false
        dragging = nil
        unlockScroll()
        if window and window.openDropdown == object then
            window.openDropdown = nil
        end
        animationToken = animationToken + 1
        local token = animationToken
        tween(fieldStroke, Tweens.Hover, { Color = hovering and Theme.LineActive or Theme.Line })
        tween(panelStroke, Tweens.Hover, { Transparency = 1 })
        tween(panel, Tweens.Hover, { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 })
        tween(holder, Tweens.Hover, { Size = UDim2.new(1, 0, 0, 0) })
        closedSignal:Fire()
        task.delay(readDuration() + 0.05, function()
            if token ~= animationToken or opened then
                return
            end
            holder.Visible = false
            panel.Size = UDim2.new(1, 0, 0, 0)
            holder.Size = UDim2.new(1, 0, 0, 0)
            panelStroke.Transparency = 1
            panel.BackgroundTransparency = 1
        end)
    end

    local open = function()
        if opened or locked then
            return
        end
        if window and window.openDropdown and window.openDropdown ~= object then
            safeCall(function()
                window.openDropdown:Close()
            end)
        end
        opened = true
        openedAt = os.clock()
        if window then
            window.openDropdown = object
        end
        animationToken = animationToken + 1
        holder.Visible = true
        tween(fieldStroke, Tweens.Hover, { Color = Theme.LineActive })
        tween(panelStroke, Tweens.Hover, { Transparency = 0 })
        tween(panel, Tweens.Hover, { BackgroundTransparency = 0 })
        updateHeight(false)
        openedSignal:Fire()
    end

    local applyTexts = function()
        local title = titleKey == "" and "" or translateText(section, titleKey)
        local description = descriptionKey == "" and "" or translateText(section, descriptionKey)
        titleLabel.Text = title
        titleLabel.Visible = title ~= ""
        descriptionLabel.Text = description
        descriptionLabel.Visible = description ~= ""
        local hasDescription = description ~= ""
        local padTop = hasDescription and 2 or math.max(0, math.floor((dims.Field - 16) / 2))
        textPadding.PaddingTop = UDim.new(0, padTop)
        textPadding.PaddingBottom = UDim.new(0, hasDescription and 4 or 0)
    end

    local applyLock = function()
        local fade = locked and LockedFade or 0
        titleLabel.TextTransparency = fade
        descriptionLabel.TextTransparency = fade
        field.BackgroundTransparency = fade
        hexBox.TextTransparency = fade
        render()
        if locked then
            close()
        end
    end

    local applyLayout = function()
        touchMode = isTouchMode()
        dims = measure(touchMode)
        top.Size = UDim2.new(1, 0, 0, dims.Field)
        textBlock.Size = UDim2.new(1, -(dims.FieldWidth + 10), 0, 0)
        field.Size = UDim2.new(0, dims.FieldWidth, 0, dims.Field)
        fieldLabel.TextSize = dims.Text
        satMap.Size = UDim2.new(1, 0, 0, dims.Map)
        satCursor.Size = UDim2.fromOffset(dims.Cursor, dims.Cursor)
        hueSlider.Size = UDim2.new(1, 0, 0, dims.Bar)
        alphaSlider.Size = UDim2.new(1, 0, 0, dims.Bar)
        hexBox.Size = UDim2.new(1, 0, 0, dims.Hex)
        hexBox.TextSize = dims.Text
        applyTexts()
        updateHeight(true)
    end

    field.InputBegan:Connect(function(input)
        if isPointerInput(input) then
            calibrate(field, input)
        end
    end)

    field.MouseEnter:Connect(function()
        hovering = true
        if not locked and not opened then
            tween(fieldStroke, Tweens.Hover, { Color = Theme.LineActive })
        end
    end)

    field.MouseLeave:Connect(function()
        hovering = false
        if not opened then
            tween(fieldStroke, Tweens.Hover, { Color = Theme.Line })
        end
    end)

    section:Connect(field.Activated, function()
        if locked then
            return
        end
        if opened then
            close()
        else
            open()
        end
    end)

    section:Connect(UserInputService.InputBegan, function(input)
        if not opened or dragging then
            return
        end
        if input.KeyCode == Enum.KeyCode.Escape then
            close()
            return
        end
        if not isPointerInput(input) then
            return
        end
        local now = os.clock()
        if now - openedAt < 0.1 or now - dragEndedAt < 0.1 then
            return
        end
        local position = Vector2.new(input.Position.X, input.Position.Y)
        if not pointInside(field, position) and not pointInside(panel, position) then
            close()
        end
    end)

    section:Connect(UserInputService.LastInputTypeChanged, function()
        if isTouchMode() ~= touchMode then
            applyLayout()
        end
    end)

    function object:Get()
        return current
    end

    function object:GetValue()
        return current
    end

    function object:GetColor()
        return current
    end

    function object:GetHex()
        return toHex(current)
    end

    function object:GetTransparency()
        return transparency
    end

    function object:GetRGB()
        return math.round(current.R * 255), math.round(current.G * 255), math.round(current.B * 255)
    end

    function object:GetHSV()
        return hue, sat, vib
    end

    function object:Set(color, newTransparency, fire)
        if typeof(color) ~= "Color3" then
            report("Warning", "ColorPicker", "Set expects a Color3")
            return
        end
        current = color
        hue, sat, vib = Color3.toHSV(color)
        if allowAlpha and newTransparency ~= nil then
            transparency = math.clamp(tonumber(newTransparency) or 0, 0, 1)
        end
        render()
        if fire == true then
            fireChange()
        end
    end

    function object:SetValue(color, newTransparency, fire)
        object:Set(color, newTransparency, fire)
    end

    function object:SetColor(color, fire)
        object:Set(color, nil, fire)
    end

    function object:SetHex(text, fire)
        local parsed = parseHex(text)
        if not parsed then
            report("Warning", "ColorPicker", "Invalid hex: " .. tostring(text))
            return false
        end
        object:Set(parsed, nil, fire)
        return true
    end

    function object:SetTransparency(value, fire)
        if not allowAlpha then
            return
        end
        transparency = math.clamp(tonumber(value) or 0, 0, 1)
        render()
        if fire == true then
            fireChange()
        end
    end

    function object:SetAllowAlpha(state)
        allowAlpha = state == true
        alphaSlider.Visible = allowAlpha
        if not allowAlpha then
            transparency = 0
        end
        render()
        updateHeight(false)
    end

    function object:IsAlphaAllowed()
        return allowAlpha
    end

    function object:SetCallback(newCallback)
        if type(newCallback) == "function" then
            callback = newCallback
        end
    end

    function object:OnChanged(listener)
        return changedSignal:Connect(listener)
    end

    function object:OnOpened(listener)
        return openedSignal:Connect(listener)
    end

    function object:OnClosed(listener)
        return closedSignal:Connect(listener)
    end

    function object:Open()
        open()
    end

    function object:Close()
        close()
    end

    function object:ToggleOpen()
        if opened then
            close()
        else
            open()
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
    end

    function object:GetDescription()
        return descriptionKey
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
            close()
        end
    end

    function object:Update(values)
        if type(values) ~= "table" then
            report("Warning", "ColorPicker", "Update needs a table")
            return false
        end
        local newName = values.Name or values.Title
        if newName ~= nil then
            titleKey = tostring(newName)
        end
        if values.Description ~= nil then
            descriptionKey = tostring(values.Description)
        end
        if type(values.Callback) == "function" then
            callback = values.Callback
        end
        if values.AllowAlpha ~= nil then
            object:SetAllowAlpha(values.AllowAlpha)
        end
        if values.Locked ~= nil then
            object:SetLocked(values.Locked)
        end
        if values.Visible ~= nil then
            object:SetVisible(values.Visible)
        end
        applyTexts()
        local newColor = values.Value
        if newColor == nil then
            newColor = values.Default
        end
        if newColor == nil then
            newColor = values.Color
        end
        if newColor ~= nil then
            object:Set(newColor, values.Transparency, values.Fire == true)
        elseif values.Transparency ~= nil then
            object:SetTransparency(values.Transparency, values.Fire == true)
        end
        return true
    end

    function object:Refresh()
        applyLayout()
        applyTexts()
        applyLock()
        render()
    end

    function object:Destroy()
        if window and window.openDropdown == object then
            window.openDropdown = nil
        end
        opened = false
        dragging = nil
        unlockScroll()
        changedSignal:Clear()
        openedSignal:Clear()
        closedSignal:Clear()
        row:Destroy()
    end

    object:Refresh()
    onLanguage(section, function()
        applyTexts()
    end)

    return object
end

MiniElements.Register("ColorPicker", function(section, options)
    local ok, result = pcall(constructColorPicker, section, options)
    if not ok then
        warn("[ColorPicker] " .. tostring(result))
        error(result, 0)
    end
    return result
end)