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
local LockedFade = 0.5

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

-- // Signals
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

-- // Platform
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

-- // Toggle
local constructToggle = function(section, options)
    local window = section.Window
    local touchMode = isTouchMode()
    local rowHeight = touchMode and 42 or 34
    local trackWidth = 40
    local trackHeight = 22
    local knobSize = 16
    local knobPadding = 3
    local keyWidth = touchMode and 64 or 58
    local keyHeight = touchMode and 28 or 22
    local keyGap = 6
    local hasKeybind = options.Keybind ~= false
    local reserved = trackWidth + 8
    if hasKeybind then
        reserved = reserved + keyWidth + keyGap
    end
    local current = options.Default == true
    local callback = options.Callback
    local boundKey = resolveKey(options.Keybind)
    local locked = options.Locked == true
    local capturing = false
    local captureConnection = nil
    local captureEndedAt = 0
    local titleKey = resolveName(options)
    local descriptionKey = options.Description ~= nil and tostring(options.Description) or ""
    local changedSignal = newSignal()
    local keySignal = newSignal()
    local keyButton = nil
    local keyStroke = nil

    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, rowHeight),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, section.Frame)

    local touchArea = create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        Visible = touchMode
    }, row)

    local textHolder = create("Frame", {
        Size = UDim2.new(1, -reserved, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, row)
    local textPadding = create("UIPadding", {
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

    local object = { Frame = row }

    -- // Name
    local applyTexts = function()
        titleLabel.Text = translateText(section, titleKey)
        local description = descriptionKey == "" and "" or translateText(section, descriptionKey)
        descriptionLabel.Text = description
        descriptionLabel.Visible = description ~= ""
    end

    -- // Lock
    local applyLock = function()
        local fade = locked and LockedFade or 0
        titleLabel.TextTransparency = fade
        descriptionLabel.TextTransparency = fade
        track.BackgroundTransparency = fade
        knob.BackgroundTransparency = fade
        if keyButton then
            keyButton.BackgroundTransparency = fade
            keyButton.TextTransparency = fade
        end
    end

    -- // Layout
    local applyLayout = function()
        touchMode = isTouchMode()
        rowHeight = touchMode and 42 or 34
        keyWidth = touchMode and 64 or 58
        keyHeight = touchMode and 28 or 22
        reserved = trackWidth + 8
        if hasKeybind then
            reserved = reserved + keyWidth + keyGap
        end
        row.Size = UDim2.new(1, 0, 0, rowHeight)
        textHolder.Size = UDim2.new(1, -reserved, 0, 0)
        local verticalPadding = UDim.new(0, math.floor((rowHeight - 16) / 2))
        textPadding.PaddingTop = verticalPadding
        textPadding.PaddingBottom = verticalPadding
        touchArea.Visible = touchMode
        if keyButton then
            keyButton.Size = UDim2.new(0, keyWidth, 0, keyHeight)
            keyButton.Position = UDim2.new(1, -(trackWidth + keyGap), 0.5, 0)
        end
    end

    -- // State
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

    -- // Keybind
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

    local commitKey = function(newKey)
        if boundKey == newKey then
            return
        end
        boundKey = newKey
        refreshKey()
        keySignal:Fire(boundKey)
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
        if locked or os.clock() - captureEndedAt < 0.25 then
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
            if input.UserInputType == Enum.UserInputType.Touch then
                stopCapture()
                return
            end
            local picked = readCapturedInput(input)
            if not picked then
                return
            end
            if picked == Enum.KeyCode.Escape or picked == Enum.KeyCode.Backspace then
                picked = nil
            end
            commitKey(picked)
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
    end

    section:Connect(UserInputService.InputBegan, function(input, gameProcessed)
        if gameProcessed or locked or not boundKey or isCapturing() then
            return
        end
        if matchesBinding(input, boundKey) then
            object:Set(not current, true)
        end
    end)

    section:Connect(UserInputService.LastInputTypeChanged, function()
        if isTouchMode() ~= touchMode then
            applyLayout()
        end
    end)

    -- // Toggle Input
    section:Connect(track.Activated, function()
        if locked then
            return
        end
        object:Set(not current, true)
    end)

    section:Connect(touchArea.Activated, function()
        if locked then
            return
        end
        object:Set(not current, true)
    end)

    -- // Toggle API
    function object:Get()
        return current
    end

    function object:GetValue()
        return current
    end

    function object:Set(value, fire)
        current = value == true
        update(false)
        if fire == true then
            safeCall(callback, current)
            changedSignal:Fire(current)
        end
    end

    function object:SetValue(value, fire)
        object:Set(value, fire)
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

    -- // Events API
    function object:SetCallback(newCallback)
        if type(newCallback) == "function" then
            callback = newCallback
        end
    end

    function object:OnChanged(listener)
        return changedSignal:Connect(listener)
    end

    function object:OnKeyChanged(listener)
        return keySignal:Connect(listener)
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

    function object:GetDescription()
        return descriptionKey
    end

    -- // Keybind API
    function object:SetKey(key)
        if key == nil or key == "None" then
            commitKey(nil)
            return true
        end
        local resolved = resolveKey(key)
        if not resolved then
            report("Warning", "Toggle", "Invalid keybind: " .. tostring(key))
            return false
        end
        commitKey(resolved)
        return true
    end

    function object:GetKey()
        return boundKey
    end

    function object:ClearKey()
        commitKey(nil)
    end

    -- // Lock API
    function object:SetLocked(state)
        locked = state == true
        if locked then
            stopCapture()
        end
        applyLock()
    end

    function object:IsLocked()
        return locked
    end

    function object:SetVisible(state)
        row.Visible = state == true
    end

    -- // Update API
    function object:Update(values)
        if type(values) ~= "table" then
            report("Warning", "Toggle", "Update needs a table")
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
        if values.Keybind == false then
            commitKey(nil)
        elseif values.Keybind ~= nil then
            object:SetKey(values.Keybind)
        end
        if values.Locked ~= nil then
            object:SetLocked(values.Locked)
        end
        if values.Visible ~= nil then
            object:SetVisible(values.Visible)
        end
        applyTexts()
        local newValue = values.Value
        if newValue == nil then
            newValue = values.Default
        end
        if newValue ~= nil then
            object:Set(newValue, values.Fire == true)
        end
        return true
    end

    function object:Refresh()
        applyLayout()
        applyTexts()
        applyLock()
        refreshKey()
        update(true)
    end

    function object:Destroy()
        stopCapture()
        changedSignal:Clear()
        keySignal:Clear()
        row:Destroy()
    end

    -- // Initialize
    object:Refresh()
    onLanguage(section, function()
        applyTexts()
        refreshKey()
    end)

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
                    commitKey(nil)
                    return
                end
                local resolved = resolveKey(value)
                if resolved then
                    commitKey(resolved)
                end
            end
        }
        window:_registerFlag(base, keyProxy, nil)
    end

    return object
end

-- // Register
MiniElements.Register("Toggle", constructToggle)