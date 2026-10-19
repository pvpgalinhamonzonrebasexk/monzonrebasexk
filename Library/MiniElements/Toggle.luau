-- // Imports
local env = getgenv and getgenv() or _G
local Library = env.MiniLibrary
local MiniElements = env.MiniElements

if type(Library) ~= "table" or type(MiniElements) ~= "table" then
    return
end

local UserInputService = game:GetService("UserInputService")

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

local PressedColor = Color3.fromRGB(96, 96, 105)

-- // Translation
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

-- // Keybind Inputs
local MouseButtons = {
    Enum.UserInputType.MouseButton1,
    Enum.UserInputType.MouseButton2,
    Enum.UserInputType.MouseButton3
}

local MouseAliases = {
    Mouse1 = Enum.UserInputType.MouseButton1,
    Mouse2 = Enum.UserInputType.MouseButton2,
    Mouse3 = Enum.UserInputType.MouseButton3
}

local IgnoredGamepadKeys = {
    [Enum.KeyCode.Thumbstick1] = true,
    [Enum.KeyCode.Thumbstick2] = true
}

local isBindable = function(item)
    if typeof(item) ~= "EnumItem" then
        return false
    end
    if item.EnumType == Enum.KeyCode then
        return item ~= Enum.KeyCode.Unknown
    end
    return table.find(MouseButtons, item) ~= nil
end

local resolveKey = function(value)
    if isBindable(value) then
        return value
    end
    if type(value) ~= "string" then
        return nil
    end
    local alias = MouseAliases[value]
    if alias then
        return alias
    end
    local item = Library:_keyFromName(value)
    if isBindable(item) then
        return item
    end
    return nil
end

local keyDisplay = function(item)
    if item.EnumType == Enum.UserInputType then
        return "Mouse " .. item.Name:match("%d+")
    end
    local name = item.Name
    name = name:gsub("^Left", "L")
    name = name:gsub("^Right", "R")
    return name
end

local readCapturedInput = function(input)
    local inputType = input.UserInputType
    if inputType == Enum.UserInputType.Keyboard then
        if input.KeyCode ~= Enum.KeyCode.Unknown then
            return input.KeyCode
        end
        return nil
    end
    if table.find(MouseButtons, inputType) then
        return inputType
    end
    if inputType.Name:find("^Gamepad") then
        local keyCode = input.KeyCode
        if keyCode ~= Enum.KeyCode.Unknown and not IgnoredGamepadKeys[keyCode] then
            return keyCode
        end
    end
    return nil
end

local matchesBinding = function(input, binding)
    if binding.EnumType == Enum.KeyCode then
        return input.KeyCode == binding
    end
    return input.UserInputType == binding
end

-- // Toggle
local constructToggle = function(section, options)
    local window = section.Window
    local touch = UserInputService.TouchEnabled
    local rowHeight = touch and 42 or 34
    local trackWidth = 40
    local trackHeight = 22
    local knobSize = 16
    local knobPadding = 3
    local keyWidth = 58
    local keyHeight = 22
    local keyGap = 6
    local hasKeybind = options.Keybind ~= false
    local reserved = trackWidth + 8
    if hasKeybind then
        reserved = reserved + keyWidth + keyGap
    end
    local current = options.Default == true
    local callback = options.Callback
    local boundKey = resolveKey(options.Keybind)
    local capturing = false
    local captureConnection = nil
    local captureEndedAt = 0
    local titleKey = resolveName(options)
    local descriptionKey = options.Description ~= nil and tostring(options.Description) or ""

    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, rowHeight),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, section.Frame)

    local textHolder = create("Frame", {
        Size = UDim2.new(1, -reserved, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, row)
    create("UIPadding", {
        PaddingTop = UDim.new(0, math.floor((rowHeight - 16) / 2)),
        PaddingBottom = UDim.new(0, math.floor((rowHeight - 16) / 2))
    }, textHolder)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2)
    }, textHolder)

    local titleLabel = createLabel(textHolder, translateText(section, titleKey), 0)
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
    }, textHolder)

    local applyTexts = function()
        titleLabel.Text = translateText(section, titleKey)
        local description = descriptionKey == "" and "" or translateText(section, descriptionKey)
        descriptionLabel.Text = description
        descriptionLabel.Visible = description ~= ""
    end

    local track = create("TextButton", {
        Size = UDim2.new(0, trackWidth, 0, trackHeight),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = ""
    }, row)
    addCorner(track, trackHeight / 2)
    addStroke(track, Theme.Line, 1)

    local knob = create("Frame", {
        Size = UDim2.new(0, knobSize, 0, knobSize),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, knobPadding, 0.5, 0),
        BackgroundColor3 = Theme.TextSecondary,
        BorderSizePixel = 0
    }, track)
    addCorner(knob, knobSize / 2)

    local update = function(instant)
        local trackColor = current and Theme.LineActive or Theme.Card
        local knobColor = current and Theme.TextPrimary or Theme.TextSecondary
        local knobX = current and (trackWidth - knobSize - knobPadding) or knobPadding
        local knobPosition = UDim2.new(0, knobX, 0.5, 0)
        if instant then
            cancelTween(track)
            cancelTween(knob)
            track.BackgroundColor3 = trackColor
            knob.BackgroundColor3 = knobColor
            knob.Position = knobPosition
            return
        end
        tween(track, Tweens.Hover, { BackgroundColor3 = trackColor })
        tween(knob, Tweens.Hover, { BackgroundColor3 = knobColor, Position = knobPosition })
    end

    local object = { Frame = row }

    -- // Keybind
    local keyButton = nil
    local keyStroke = nil

    local refreshKey = function()
        if not keyButton then
            return
        end
        if capturing then
            keyButton.Text = translateText(section, "Press...")
        elseif boundKey then
            keyButton.Text = keyDisplay(boundKey)
        else
            keyButton.Text = translateText(section, "None")
        end
        local color = capturing and Theme.LineActive or Theme.Line
        tween(keyStroke, Tweens.Hover, { Color = color })
    end

    local isCapturing = function()
        return capturing or (window ~= nil and window.capturingKey == true)
    end

    local stopCapture = function()
        if captureConnection then
            captureConnection:Disconnect()
            captureConnection = nil
        end
        if not capturing then
            return
        end
        capturing = false
        captureEndedAt = os.clock()
        task.defer(function()
            if window then
                window.capturingKey = false
            end
        end)
        refreshKey()
    end

    local startCapture = function()
        if os.clock() - captureEndedAt < 0.25 then
            return
        end
        if capturing then
            stopCapture()
            return
        end
        if window and window.capturingKey then
            return
        end
        capturing = true
        if window then
            window.capturingKey = true
        end
        refreshKey()
        captureConnection = section:Connect(UserInputService.InputBegan, function(input)
            local picked = readCapturedInput(input)
            if not picked then
                return
            end
            if picked == Enum.KeyCode.Escape or picked == Enum.KeyCode.Backspace then
                picked = nil
            end
            boundKey = picked
            stopCapture()
        end)
    end

    if hasKeybind then
        keyButton = create("TextButton", {
            Size = UDim2.new(0, keyWidth, 0, keyHeight),
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -(trackWidth + keyGap), 0.5, 0),
            BackgroundColor3 = Theme.Card,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            TextColor3 = Theme.TextPrimary,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextTruncate = Enum.TextTruncate.AtEnd
        }, row)
        addCorner(keyButton, 6)
        keyStroke = addStroke(keyButton, Theme.Line, 1)
        section:Connect(keyButton.MouseEnter, function()
            tween(keyButton, Tweens.Hover, { BackgroundColor3 = Theme.LineActive })
        end)
        section:Connect(keyButton.MouseLeave, function()
            tween(keyButton, Tweens.Hover, { BackgroundColor3 = Theme.Card })
        end)
        section:Connect(keyButton.InputBegan, function(input)
            if isPointerInput(input) then
                tween(keyButton, Tweens.Hover, { BackgroundColor3 = PressedColor })
            end
        end)
        section:Connect(keyButton.InputEnded, function(input)
            if isPointerInput(input) then
                tween(keyButton, Tweens.Hover, { BackgroundColor3 = Theme.Card })
            end
        end)
        section:Connect(keyButton.Activated, startCapture)
        section:Connect(UserInputService.InputBegan, function(input, gameProcessed)
            if gameProcessed or not boundKey or isCapturing() then
                return
            end
            if matchesBinding(input, boundKey) then
                object:Set(not current, true)
            end
        end)
    end

    -- // Name
    applyTexts()
    update(true)
    refreshKey()
    onLanguage(section, function()
        applyTexts()
        refreshKey()
    end)

    -- // Toggle Input
    section:Connect(track.Activated, function()
        object:Set(not current, true)
    end)

    -- // Toggle API
    function object:Get()
        return current
    end

    function object:Set(value, fire)
        current = value == true
        update(false)
        if fire then
            safeCall(callback, current)
        end
    end

    function object:Toggle()
        object:Set(not current, true)
    end

    function object:Enable()
        if not current then
            object:Set(true, true)
        end
    end

    function object:Disable()
        if current then
            object:Set(false, true)
        end
    end

    function object:SetCallback(newCallback)
        if type(newCallback) == "function" then
            callback = newCallback
        end
    end

    function object:SetVisible(state)
        row.Visible = state == true
    end

    function object:Destroy()
        stopCapture()
        row:Destroy()
    end

    -- // Name API
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

    -- // Keybind API
    function object:SetKey(key)
        if key == nil or key == "None" then
            boundKey = nil
            refreshKey()
            return true
        end
        local resolved = resolveKey(key)
        if not resolved then
            report("Warning", "Toggle", "Invalid keybind: " .. tostring(key))
            return false
        end
        boundKey = resolved
        refreshKey()
        return true
    end

    function object:GetKey()
        return boundKey
    end

    function object:ClearKey()
        boundKey = nil
        refreshKey()
    end

    -- // Keybind Save
    local canSave = hasKeybind
        and options.Save ~= false
        and window ~= nil
        and type(window._registerFlag) == "function"
        and type(window.flags) == "table"

    if canSave then
        local label = resolveName(options)
        if label == "" then
            label = "Toggle"
        end
        local tabName = section.Tab and section.Tab.name or "Tab"
        local base = tabName .. "/" .. tostring(section.title) .. "/" .. label .. "/Keybind"
        if type(options.Flag) == "string" and options.Flag ~= "" then
            base = options.Flag .. "/Keybind"
        end
        local counts = section.flagCounts
        if type(counts) == "table" then
            counts[base] = (counts[base] or 0) + 1
            if counts[base] > 1 then
                base = base .. "#" .. counts[base]
            end
        end
        local keyProxy = {
            Get = function()
                return boundKey and boundKey.Name or "None"
            end,
            Set = function(_, value)
                if value == "None" then
                    boundKey = nil
                    refreshKey()
                    return
                end
                local resolved = resolveKey(value)
                if resolved then
                    boundKey = resolved
                    refreshKey()
                end
            end
        }
        window:_registerFlag(base, keyProxy, nil)
    end

    return object
end

-- // Register
MiniElements.Register("Toggle", constructToggle)