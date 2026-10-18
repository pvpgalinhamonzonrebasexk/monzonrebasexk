-- // Environment
local env = getgenv and getgenv() or _G
local Library = env.MiniLibrary

if type(Library) ~= "table" then
    return
end

-- // Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer

-- // Imports
local Theme = Library.Theme
local Tweens = Library.Tweens
local tween = Library.Tween
local cancelTween = Library.CancelTween
local create = Library.Create
local addCorner = Library.AddCorner
local addStroke = Library.AddStroke
local isPointerInput = Library.IsPointerInput
local createLabel = Library.CreateLabel
local resolveName = Library.ResolveName
local resolveIcon = Library.GetIcon
local report = Library.Report
local trim = Library.Trim
local safeCall = Library.SafeCall
local getViewport = Library.GetViewport
local Loader = Library.Loader

local PressedColor = Color3.fromRGB(96, 96, 105)

-- // Helpers
local hasTouch = function()
    return UserInputService.TouchEnabled
end

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

local normalizeEntries = function(list)
    local entries = {}
    for _, option in ipairs(list or {}) do
        if type(option) == "table" then
            entries[#entries + 1] = {
                Value = option.Value,
                Text = tostring(option.Text or option.Name or option.Value)
            }
        else
            entries[#entries + 1] = { Value = option, Text = tostring(option) }
        end
    end
    return entries
end

local findEntry = function(entries, value)
    for _, entry in ipairs(entries) do
        if entry.Value == value then
            return entry
        end
    end
    return nil
end

local newRow = function(parent, height)
    return create("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, parent)
end

local createNameLabel = function(section, parent, text, space)
    local key = tostring(text or "")
    local label = createLabel(parent, translateText(section, key), space)
    onLanguage(section, function()
        label.Text = translateText(section, key)
    end)
    return label
end

local createHeader = function(section, options, rightWidth, minHeight)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, minHeight),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1
    }, section.Frame)
    local left = create("Frame", {
        Size = UDim2.new(1, -(rightWidth + 8), 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, row)
    local padding = math.floor((minHeight - 16) / 2)
    create("UIPadding", {
        PaddingTop = UDim.new(0, padding),
        PaddingBottom = UDim.new(0, padding)
    }, left)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2)
    }, left)
    local titleKey = resolveName(options)
    local descriptionKey = options.Description ~= nil and tostring(options.Description) or ""
    local titleLabel = createLabel(left, translateText(section, titleKey), 0)
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
    }, left)
    local applyDescription = function()
        local text = descriptionKey == "" and "" or translateText(section, descriptionKey)
        descriptionLabel.Text = text
        descriptionLabel.Visible = text ~= ""
    end
    applyDescription()
    onLanguage(section, function()
        titleLabel.Text = translateText(section, titleKey)
        applyDescription()
    end)
    return { Row = row, Title = titleLabel }
end

-- // Elements
local Elements = {}

-- // Button
Elements.Button = function(section, options)
    local touch = hasTouch()
    local full = options.Full == true
    local rowHeight = touch and 42 or 34
    local buttonHeight = touch and 36 or 30
    local buttonWidth = touch and 124 or 116
    local hovered = false
    local pressed = false
    local row = newRow(section.Frame, rowHeight)
    if not full then
        createNameLabel(section, row, resolveName(options), buttonWidth + 8)
    end
    local textKey = options.ButtonText
    if textKey == nil then
        textKey = full and resolveName(options) or "Run"
    end
    textKey = tostring(textKey)
    local button = create("TextButton", {
        Size = full and UDim2.new(1, 0, 0, buttonHeight) or UDim2.new(0, buttonWidth, 0, buttonHeight),
        AnchorPoint = full and Vector2.new(0.5, 0.5) or Vector2.new(1, 0.5),
        Position = full and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(1, 0, 0.5, 0),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = translateText(section, textKey),
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextTruncate = Enum.TextTruncate.AtEnd
    }, row)
    addCorner(button, 6)
    addStroke(button, Theme.Line, 1)
    onLanguage(section, function()
        button.Text = translateText(section, textKey)
    end)
    local refresh = function()
        local color = Theme.Card
        if pressed then
            color = PressedColor
        elseif hovered then
            color = Theme.LineActive
        end
        tween(button, Tweens.Hover, { BackgroundColor3 = color })
    end
    section:Connect(button.MouseEnter, function()
        hovered = true
        refresh()
    end)
    section:Connect(button.MouseLeave, function()
        hovered = false
        pressed = false
        refresh()
    end)
    section:Connect(button.InputBegan, function(input)
        if isPointerInput(input) then
            pressed = true
            refresh()
        end
    end)
    section:Connect(button.InputEnded, function(input)
        if isPointerInput(input) then
            pressed = false
            if input.UserInputType == Enum.UserInputType.Touch then
                hovered = false
            end
            refresh()
        end
    end)
    section:Connect(button.Activated, function()
        safeCall(options.Callback)
    end)
    local object = { Frame = row, Button = button }
    function object:SetText(text)
        textKey = tostring(text or "")
        button.Text = translateText(section, textKey)
    end
    function object:GetText()
        return button.Text
    end
    return object
end

-- // Slider
Elements.Slider = function(section, options)
    local touch = hasTouch()
    local min = tonumber(options.Min) or 0
    local max = tonumber(options.Max) or 100
    local step = tonumber(options.Step) or 1
    if step <= 0 then
        step = 1
    end
    local format = options.Format
    if type(format) ~= "function" then
        format = function(value)
            return tostring(value)
        end
    end
    local snap = function(value)
        value = math.floor((value - min) / step + 0.5) * step + min
        value = tonumber(string.format("%.6f", value)) or value
        return math.clamp(value, min, max)
    end
    local current = snap(tonumber(options.Default) or min)
    local rowHeight = touch and 58 or 48
    local knobSize = touch and 20 or 14
    local knobActive = knobSize + 4
    local trackHeight = touch and 8 or 6
    local headerHeight = 20
    local row = newRow(section.Frame, rowHeight)
    local label = createNameLabel(section, row, resolveName(options), 74)
    label.Size = UDim2.new(1, -74, 0, headerHeight)
    local valueLabel = create("TextLabel", {
        Size = UDim2.new(0, 70, 0, headerHeight),
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        TextColor3 = Theme.TextSecondary,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Right
    }, row)
    local track = create("Frame", {
        Size = UDim2.new(1, -knobSize, 0, trackHeight),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, knobSize / 2, 0, headerHeight + (rowHeight - headerHeight) / 2),
        BackgroundColor3 = Theme.Line,
        BorderSizePixel = 0
    }, row)
    addCorner(track, trackHeight / 2)
    local fill = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.TextPrimary,
        BorderSizePixel = 0
    }, track)
    addCorner(fill, trackHeight / 2)
    local knob = create("Frame", {
        Size = UDim2.new(0, knobSize, 0, knobSize),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Theme.TextPrimary,
        BorderSizePixel = 0,
        ZIndex = 2
    }, track)
    addCorner(knob, knobActive)
    addStroke(knob, Theme.LineActive, 1)
    local hit = create("TextButton", {
        Size = UDim2.new(1, 0, 0, rowHeight - headerHeight),
        Position = UDim2.new(0, 0, 0, headerHeight),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false
    }, row)
    local page = section.Tab and section.Tab.Page
    local dragging = false
    local activeInput = nil
    local update = function()
        local alpha = math.clamp((current - min) / math.max(max - min, 1e-9), 0, 1)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = tostring(format(current))
    end
    local setScroll = function(state)
        if page then
            page.ScrollingEnabled = state
        end
    end
    local setFromX = function(x)
        local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local value = snap(min + alpha * (max - min))
        if value == current then
            return
        end
        current = value
        if options.Commit ~= true then
            safeCall(options.Callback, current)
        end
        update()
    end
    local finish = function()
        if not dragging then
            return
        end
        dragging = false
        activeInput = nil
        setScroll(true)
        tween(knob, Tweens.Hover, { Size = UDim2.new(0, knobSize, 0, knobSize) })
        if options.Commit == true then
            safeCall(options.Callback, current)
        end
        safeCall(options.OnCommit, current)
        update()
    end
    section:Connect(hit.InputBegan, function(input)
        if dragging or not isPointerInput(input) then
            return
        end
        dragging = true
        activeInput = input
        setScroll(false)
        tween(knob, Tweens.Hover, { Size = UDim2.new(0, knobActive, 0, knobActive) })
        setFromX(input.Position.X)
    end)
    section:Connect(UserInputService.InputChanged, function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input == activeInput then
            setFromX(input.Position.X)
        end
    end)
    section:Connect(UserInputService.InputEnded, function(input)
        if not dragging or not activeInput then
            return
        end
        local sameInput = input == activeInput
        local sameMouse = activeInput.UserInputType ~= Enum.UserInputType.Touch
            and input.UserInputType == activeInput.UserInputType
        local ended = activeInput.UserInputState == Enum.UserInputState.End
        if sameInput or sameMouse or ended then
            finish()
        end
    end)
    update()
    local object = { Frame = row }
    function object:Get()
        return current
    end
    function object:Set(value, fire)
        current = snap(tonumber(value) or current)
        update()
        if fire then
            safeCall(options.Callback, current)
        end
    end
    return object
end

-- // Choice
Elements.Choice = function(section, options)
    local touch = hasTouch()
    local entries = normalizeEntries(options.Options or options.Values)
    local current = options.Default
    if current == nil and entries[1] then
        current = entries[1].Value
    end
    local count = math.max(#entries, 1)
    local rowHeight = touch and 42 or 34
    local buttonHeight = touch and 36 or 30
    local width = math.max(touch and 150 or 136, (touch and 72 or 64) * count)
    local row = newRow(section.Frame, rowHeight)
    createNameLabel(section, row, resolveName(options), width + 8)
    local holder = create("Frame", {
        Size = UDim2.new(0, width, 0, buttonHeight),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        BackgroundTransparency = 1
    }, row)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, holder)
    local items = {}
    local refresh = function()
        for _, item in ipairs(items) do
            local selected = item.value == current
            tween(item.button, Tweens.Hover, {
                BackgroundColor3 = selected and Theme.LineActive or Theme.Card
            })
        end
    end
    for index, entry in ipairs(entries) do
        local button = create("TextButton", {
            Size = UDim2.new(1 / count, -(4 * (count - 1)) / count, 1, 0),
            BackgroundColor3 = Theme.Card,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = translateText(section, entry.Text),
            TextColor3 = Theme.TextPrimary,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            TextTruncate = Enum.TextTruncate.AtEnd,
            LayoutOrder = index
        }, holder)
        addCorner(button, 6)
        addStroke(button, Theme.Line, 1)
        items[index] = { button = button, value = entry.Value, entry = entry }
        section:Connect(button.Activated, function()
            if current == entry.Value then
                return
            end
            current = entry.Value
            refresh()
            safeCall(options.Callback, current)
        end)
    end
    onLanguage(section, function()
        for _, item in ipairs(items) do
            item.button.Text = translateText(section, item.entry.Text)
        end
    end)
    refresh()
    local object = { Frame = row }
    function object:Get()
        return current
    end
    function object:Set(value, fire)
        if not findEntry(entries, value) then
            return
        end
        current = value
        refresh()
        if fire then
            safeCall(options.Callback, current)
        end
    end
    return object
end

-- // Input
Elements.Input = function(section, options)
    local touch = hasTouch()
    local rowHeight = touch and 44 or 34
    local boxHeight = touch and 36 or 30
    local labelWidth = tonumber(options.LabelWidth) or 54
    local hasButton = options.ButtonText ~= nil
    local buttonWidth = touch and 72 or 64
    local gap = 6
    local reserved = hasButton and (buttonWidth + gap) or 0
    local placeholderKey = tostring(options.Placeholder or "")
    local buttonKey = tostring(options.ButtonText or "")
    local row = newRow(section.Frame, rowHeight)
    local label = createNameLabel(section, row, resolveName(options), 0)
    label.Size = UDim2.new(0, labelWidth, 1, 0)
    local box = create("TextBox", {
        Size = UDim2.new(1, -(labelWidth + gap + reserved), 0, boxHeight),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, labelWidth + gap, 0.5, 0),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        ClipsDescendants = true,
        Text = tostring(options.Default or ""),
        PlaceholderText = translateText(section, placeholderKey),
        PlaceholderColor3 = Theme.TextSecondary,
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    }, row)
    addCorner(box, 6)
    local boxStroke = addStroke(box, Theme.Line, 1)
    create("UIPadding", {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8)
    }, box)
    local button = nil
    if hasButton then
        button = create("TextButton", {
            Size = UDim2.new(0, buttonWidth, 0, boxHeight),
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            BackgroundColor3 = Theme.Card,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = translateText(section, buttonKey),
            TextColor3 = Theme.TextPrimary,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            TextTruncate = Enum.TextTruncate.AtEnd
        }, row)
        addCorner(button, 6)
        addStroke(button, Theme.Line, 1)
        section:Connect(button.MouseEnter, function()
            tween(button, Tweens.Hover, { BackgroundColor3 = Theme.LineActive })
        end)
        section:Connect(button.MouseLeave, function()
            tween(button, Tweens.Hover, { BackgroundColor3 = Theme.Card })
        end)
        section:Connect(button.InputBegan, function(input)
            if isPointerInput(input) then
                tween(button, Tweens.Hover, { BackgroundColor3 = PressedColor })
            end
        end)
        section:Connect(button.InputEnded, function(input)
            if isPointerInput(input) then
                tween(button, Tweens.Hover, { BackgroundColor3 = Theme.Card })
            end
        end)
        section:Connect(button.Activated, function()
            safeCall(options.OnSubmit, trim(box.Text))
        end)
    end
    onLanguage(section, function()
        box.PlaceholderText = translateText(section, placeholderKey)
        if button then
            button.Text = translateText(section, buttonKey)
        end
    end)
    section:Connect(box.Focused, function()
        tween(boxStroke, Tweens.Hover, { Color = Theme.TextSecondary })
    end)
    section:Connect(box.FocusLost, function(enterPressed)
        tween(boxStroke, Tweens.Hover, { Color = Theme.Line })
        local text = trim(box.Text)
        if box.Text ~= text then
            box.Text = text
        end
        safeCall(options.Callback, text, enterPressed)
        if enterPressed and hasButton then
            safeCall(options.OnSubmit, text)
        end
    end)
    local object = { Frame = row, Box = box, Button = button }
    function object:Get()
        return trim(box.Text)
    end
    function object:Set(text)
        box.Text = tostring(text or "")
    end
    function object:Focus()
        box:CaptureFocus()
    end
    function object:SetButtonText(text)
        if button then
            buttonKey = tostring(text or "")
            button.Text = translateText(section, buttonKey)
        end
    end
    return object
end

-- // Toggle
Elements.Toggle = function(section, options)
    local touch = hasTouch()
    local rowHeight = touch and 42 or 34
    local trackWidth = 40
    local trackHeight = 22
    local knobSize = 16
    local current = options.Default == true
    local row = newRow(section.Frame, rowHeight)
    createNameLabel(section, row, resolveName(options), trackWidth + 8)
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
        Position = UDim2.new(0, 3, 0.5, 0),
        BackgroundColor3 = Theme.TextSecondary,
        BorderSizePixel = 0
    }, track)
    addCorner(knob, knobSize / 2)
    local update = function(instant)
        local trackColor = current and Theme.LineActive or Theme.Card
        local knobColor = current and Theme.TextPrimary or Theme.TextSecondary
        local knobPosition = UDim2.new(0, current and (trackWidth - knobSize - 3) or 3, 0.5, 0)
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
    update(true)
    section:Connect(track.Activated, function()
        current = not current
        update(false)
        safeCall(options.Callback, current)
    end)
    local object = { Frame = row }
    function object:Get()
        return current
    end
    function object:Set(value, fire)
        current = value == true
        update(false)
        if fire then
            safeCall(options.Callback, current)
        end
    end
    return object
end

-- // Paragraph
Elements.Paragraph = function(section, options)
    local titleKey = tostring(options.Title or options.Name or "")
    local bodyKey = tostring(options.Content or options.Text or options.Description or "")
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, section.Frame)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2)
    }, row)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 4)
    }, row)
    local titleLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1
    }, row)
    local bodyLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextSecondary,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = 2
    }, row)
    local apply = function()
        local title = titleKey == "" and "" or translateText(section, titleKey)
        local body = bodyKey == "" and "" or translateText(section, bodyKey)
        titleLabel.Text = title
        titleLabel.Visible = title ~= ""
        bodyLabel.Text = body
        bodyLabel.Visible = body ~= ""
    end
    apply()
    onLanguage(section, apply)
    local object = { Frame = row }
    function object:SetText(text)
        bodyKey = tostring(text or "")
        apply()
    end
    return object
end

-- // Dropdown
Elements.Dropdown = function(section, options)
    local touch = hasTouch()
    local entries = normalizeEntries(options.Values or options.Options)
    local rowHeight = touch and 44 or 34
    local selectorHeight = touch and 36 or 30
    local optionHeight = touch and 36 or 28
    local maxListHeight = tonumber(options.MaxHeight) or (touch and 190 or 170)
    local selectorWidth = tonumber(options.Width) or (touch and 170 or 156)
    local placeholderKey = tostring(options.Placeholder or "Select...")
    local opened = false
    local openToken = 0
    local current = nil
    local items = {}
    local setOpen = nil
    local default = options.Default
    if default ~= nil and findEntry(entries, default) then
        current = default
    elseif entries[1] then
        current = entries[1].Value
    end
    local displayText = function()
        local entry = findEntry(entries, current)
        if entry then
            return translateText(section, entry.Text)
        end
        return translateText(section, placeholderKey)
    end
    local getListHeight = function()
        local content = #entries * optionHeight + math.max(#entries - 1, 0) * 2 + 8
        return math.min(content, maxListHeight)
    end
    local layout = section.Frame:FindFirstChildOfClass("UIListLayout")
    if layout then
        layout.Padding = UDim.new(0, 4)
    end
    local header = createHeader(section, options, selectorWidth, rowHeight)
    local selector = create("TextButton", {
        Size = UDim2.new(0, selectorWidth, 0, selectorHeight),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = ""
    }, header.Row)
    addCorner(selector, 6)
    local selectorStroke = addStroke(selector, Theme.Line, 1)
    local selectedLabel = create("TextLabel", {
        Size = UDim2.new(1, -34, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    }, selector)
    local arrow = create("ImageLabel", {
        Size = UDim2.new(0, 14, 0, 14),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        BackgroundTransparency = 1,
        Image = resolveIcon("chevron-down", "rbxassetid://10709790948"),
        ImageColor3 = Theme.TextSecondary
    }, selector)
    local list = create("ScrollingFrame", {
        Name = "List",
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Visible = false,
        ClipsDescendants = true,
        Active = true,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.LineActive,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        LayoutOrder = 2
    }, section.Frame)
    addCorner(list, 6)
    addStroke(list, Theme.Line, 1)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2)
    }, list)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 4),
        PaddingLeft = UDim.new(0, 4),
        PaddingRight = UDim.new(0, 4)
    }, list)
    local refresh = function()
        selectedLabel.Text = displayText()
        for _, item in ipairs(items) do
            local state = item.entry.Value == current
            tween(item.button, Tweens.Hover, { BackgroundTransparency = state and 0 or 1 })
        end
    end
    local build = function()
        for _, item in ipairs(items) do
            item.button:Destroy()
        end
        table.clear(items)
        for index, entry in ipairs(entries) do
            local button = create("TextButton", {
                Size = UDim2.new(1, 0, 0, optionHeight),
                BackgroundColor3 = Theme.LineActive,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = translateText(section, entry.Text),
                TextColor3 = Theme.TextPrimary,
                TextSize = 12,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                LayoutOrder = index
            }, list)
            addCorner(button, 5)
            create("UIPadding", {
                PaddingLeft = UDim.new(0, 8),
                PaddingRight = UDim.new(0, 8)
            }, button)
            items[index] = { button = button, entry = entry }
            button.MouseEnter:Connect(function()
                if entry.Value ~= current then
                    tween(button, Tweens.Hover, { BackgroundTransparency = 0.6 })
                end
            end)
            button.MouseLeave:Connect(function()
                if entry.Value ~= current then
                    tween(button, Tweens.Hover, { BackgroundTransparency = 1 })
                end
            end)
            button.Activated:Connect(function()
                local changed = current ~= entry.Value
                current = entry.Value
                refresh()
                setOpen(false)
                if changed then
                    safeCall(options.Callback, current)
                end
            end)
        end
        if opened then
            list.Size = UDim2.new(1, 0, 0, getListHeight())
        end
        refresh()
    end
    setOpen = function(state)
        opened = state
        openToken = openToken + 1
        local token = openToken
        tween(arrow, Tweens.Hover, { Rotation = state and 180 or 0 })
        tween(selectorStroke, Tweens.Hover, { Color = state and Theme.LineActive or Theme.Line })
        if state then
            list.Visible = true
            tween(list, Tweens.Dropdown, { Size = UDim2.new(1, 0, 0, getListHeight()) })
            return
        end
        local closing = tween(list, Tweens.Dropdown, { Size = UDim2.new(1, 0, 0, 0) })
        closing.Completed:Connect(function()
            if token == openToken and not opened then
                list.Visible = false
            end
        end)
    end
    section:Connect(selector.Activated, function()
        setOpen(not opened)
    end)
    onLanguage(section, function()
        for _, item in ipairs(items) do
            item.button.Text = translateText(section, item.entry.Text)
        end
        refresh()
    end)
    build()
    local object = { Frame = header.Row, List = list }
    function object:Get()
        return current
    end
    function object:Set(value, fire)
        if value ~= nil and not findEntry(entries, value) then
            return
        end
        current = value
        refresh()
        if fire then
            safeCall(options.Callback, current)
        end
    end
    function object:SetValues(values, keepSelection)
        entries = normalizeEntries(values)
        if not (keepSelection ~= false and findEntry(entries, current)) then
            current = entries[1] and entries[1].Value or nil
        end
        build()
    end
    return object
end

-- // Placement
local place = function(section, name, options)
    local holderSection = section:NewHolder(name)
    return Elements[name](holderSection, options)
end

-- // Servers
local Servers = {}

Library.Servers = Servers

function Servers.Fetch(url)
    local httpRequest = request or http_request or (syn and syn.request)
    local ok, body = pcall(function()
        if httpRequest then
            local response = httpRequest({ Url = url, Method = "GET" })
            if type(response) == "table" and (response.StatusCode == 200 or response.Success == true) then
                return response.Body
            end
            return nil
        end
        return game:HttpGet(url)
    end)
    if not ok or type(body) ~= "string" then
        return nil
    end
    local decoded, data = pcall(HttpService.JSONDecode, HttpService, body)
    if decoded and type(data) == "table" then
        return data
    end
    return nil
end

function Servers.Find()
    local candidates = {}
    local cursor = nil
    for _ = 1, 3 do
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        if cursor then
            url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
        end
        local data = Servers.Fetch(url)
        if not data or type(data.data) ~= "table" then
            break
        end
        for _, server in ipairs(data.data) do
            local playing = type(server) == "table" and tonumber(server.playing)
            local maxPlayers = type(server) == "table" and tonumber(server.maxPlayers)
            if playing and maxPlayers and playing < maxPlayers and server.id ~= game.JobId then
                candidates[#candidates + 1] = server.id
            end
        end
        cursor = data.nextPageCursor
        if not cursor or #candidates >= 20 then
            break
        end
    end
    if #candidates == 0 then
        return nil
    end
    return candidates[math.random(1, #candidates)]
end

function Servers.Join(jobId)
    if type(jobId) ~= "string" or jobId == "" then
        return false
    end
    local ok, err = pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, jobId, LocalPlayer)
    if not ok then
        report("Error", "Server", tostring(err))
    end
    return ok
end

function Servers.Hop()
    local jobId = Servers.Find()
    if not jobId then
        return false
    end
    return Servers.Join(jobId)
end

function Servers.Public()
    local ok, err = pcall(TeleportService.Teleport, TeleportService, game.PlaceId, LocalPlayer)
    if not ok then
        report("Error", "Server", tostring(err))
    end
    return ok
end

function Servers.Rejoin()
    if #Players:GetPlayers() <= 1 then
        LocalPlayer:Kick("Rejoining...")
        task.wait()
        return Servers.Public()
    end
    return Servers.Join(game.JobId)
end

-- // Settings API
function Library:SetSide(side, persist)
    self.settings.Side = side == "Left" and "Left" or "Right"
    if self.drawerFrame then
        cancelTween(self.drawerFrame)
        self.drawerFrame.Position = self:_drawerPosition(self.isOpen)
    end
    if persist ~= false then
        self:_saveSettings()
    end
end

function Library:SetWidth(value, persist)
    local limits = Library.SettingsLimits.Width
    value = math.clamp(math.floor(tonumber(value) or limits.Min), limits.Min, limits.Max)
    self.settings.Width = value
    self.drawerWidth = math.min(value, getViewport().X)
    if self.drawerFrame then
        cancelTween(self.drawerFrame)
        self.drawerFrame.Size = UDim2.new(0, self.drawerWidth, 1, 0)
        self.drawerFrame.Position = self:_drawerPosition(self.isOpen)
    end
    if persist ~= false then
        self:_saveSettings()
    end
end

function Library:SetTransparency(value, persist)
    local limits = Library.SettingsLimits.Transparency
    value = math.clamp(tonumber(value) or 0, limits.Min, limits.Max)
    self.settings.Transparency = value
    if self.drawerFrame then
        self.drawerFrame.BackgroundTransparency = value
    end
    if self.headerFrame then
        self.headerFrame.BackgroundTransparency = value
    end
    if persist ~= false then
        self:_saveSettings()
    end
end

function Library:SetMinimizeKey(keyCode, persist)
    if typeof(keyCode) ~= "EnumItem" then
        return
    end
    self.MinimizeKey = keyCode
    self.settings.MinimizeKey = keyCode.Name
    if persist ~= false then
        self:_saveSettings()
    end
end

function Library:SetAutoSave(state, persist)
    self.settings.AutoSave = state == true
    if persist ~= false then
        self:_saveSettings()
    end
end

function Library:ResetTogglePosition()
    if self.toggleButton then
        self.toggleButton.Position = UDim2.new(0, 20, 0.5, -Library.Metrics.ToggleSize / 2)
    end
end

function Library:ResetSettings()
    local defaults = Library.DefaultSettings
    self:SetMinimizeKey(Library:_keyFromName(defaults.MinimizeKey) or Enum.KeyCode.RightShift, false)
    self:SetSide(defaults.Side, false)
    self:SetWidth(defaults.Width, false)
    self:SetTransparency(defaults.Transparency, false)
    self:SetLanguage(defaults.Language, false)
    self:SetAutoSave(defaults.AutoSave, false)
    self:ResetTogglePosition()
    self:_saveSettings()
    if self.settingsRefresh then
        self.settingsRefresh()
    end
end

-- // Translation
Library:AddTranslations("pt", {
    ["Settings"] = "Configurações",
    ["General settings and options."] = "Ajustes e definições gerais.",
    ["Server"] = "Servidor",
    ["Job ID"] = "Job ID",
    ["Paste the Job ID"] = "Cole o Job ID",
    ["Join"] = "Entrar",
    ["Server Hop"] = "Trocar de servidor",
    ["Public Server"] = "Servidor público",
    ["Rejoin"] = "Reentrar",
    ["Working..."] = "Aguarde...",
    ["Failed"] = "Falhou",
    ["Panel Settings"] = "Configurações do painel",
    ["Panel side"] = "Lado do painel",
    ["Right"] = "Direita",
    ["Left"] = "Esquerda",
    ["Panel width"] = "Largura do painel",
    ["Panel transparency"] = "Transparência do painel",
    ["Toggle key"] = "Tecla de abrir/fechar",
    ["Press..."] = "Pressione...",
    ["Language"] = "Idioma",
    ["Interface language."] = "Idioma da interface.",
    ["Config"] = "Configuração",
    ["Save Config"] = "Salvar configuração",
    ["Load Config"] = "Carregar configuração",
    ["Delete Config"] = "Apagar configuração",
    ["Saved"] = "Salvo",
    ["Loaded"] = "Carregado",
    ["Deleted"] = "Apagado",
    ["Auto Save"] = "Salvar automaticamente",
    ["Config file"] = "Arquivo de configuração"
})

-- // Settings Tab
function Library:CreateSettingsTab()
    if self.settingsTab then
        return self.settingsTab
    end
    local tab = self:CreateTab({
        Name = "Settings",
        Description = "General settings and options.",
        Icon = "settings"
    })
    self.settingsTab = tab
    local limits = Library.SettingsLimits
    local controls = {}
    local busy = false

    pcall(function()
        self:_connect(TeleportService.TeleportInitFailed, function(player, _, message)
            if player == LocalPlayer then
                report("Warning", "Server", tostring(message))
            end
        end)
    end)

    local runAction = function(setText, textKey, action)
        if busy or self.destroyed then
            return
        end
        busy = true
        setText("Working...")
        task.spawn(function()
            local ok, result = pcall(action)
            if not ok then
                report("Error", "Server", Loader:Resolve(result))
            end
            local succeeded = ok and result == true
            if not succeeded then
                setText("Failed")
            end
            task.wait(succeeded and 8 or 2)
            busy = false
            if not self.destroyed then
                setText(textKey)
            end
        end)
    end

    local serverSection = tab:CreateSection("Server")

    controls.JobId = place(serverSection, "Input", {
        Name = "Job ID",
        Placeholder = "Paste the Job ID",
        ButtonText = "Join",
        OnSubmit = function(text)
            if text == "" then
                controls.JobId:Focus()
                return
            end
            runAction(function(value)
                controls.JobId:SetButtonText(value)
            end, "Join", function()
                return Servers.Join(text)
            end)
        end
    })

    local addServerButton = function(key, action)
        local button = nil
        button = place(serverSection, "Button", {
            Name = key,
            Full = true,
            Callback = function()
                runAction(function(value)
                    button:SetText(value)
                end, key, action)
            end
        })
        return button
    end

    controls.Hop = addServerButton("Server Hop", Servers.Hop)
    controls.Public = addServerButton("Public Server", Servers.Public)
    controls.Rejoin = addServerButton("Rejoin", Servers.Rejoin)

    local panelSection = tab:CreateSection("Panel Settings")

    controls.Side = place(panelSection, "Choice", {
        Name = "Panel side",
        Options = {
            { Value = "Right", Text = "Right" },
            { Value = "Left", Text = "Left" }
        },
        Default = self.settings.Side,
        Callback = function(value)
            self:SetSide(value)
        end
    })

    controls.Width = place(panelSection, "Slider", {
        Name = "Panel width",
        Min = limits.Width.Min,
        Max = limits.Width.Max,
        Step = limits.Width.Step,
        Default = self.settings.Width,
        Commit = true,
        Format = function(value)
            return tostring(math.floor(value)) .. "px"
        end,
        Callback = function(value)
            self:SetWidth(value)
        end
    })

    controls.Transparency = place(panelSection, "Slider", {
        Name = "Panel transparency",
        Min = limits.Transparency.Min,
        Max = limits.Transparency.Max,
        Step = limits.Transparency.Step,
        Default = self.settings.Transparency,
        Format = function(value)
            return string.format("%d%%", math.floor(value * 100 + 0.5))
        end,
        Callback = function(value)
            self:SetTransparency(value, false)
        end,
        OnCommit = function(value)
            self:SetTransparency(value)
        end
    })

    if not Library.IsMobile then
        controls.Key = place(panelSection, "Button", {
            Name = "Toggle key",
            ButtonText = self.MinimizeKey.Name,
            Callback = function()
                local keyControl = controls.Key
                if not keyControl or self.capturingKey then
                    return
                end
                self.capturingKey = true
                keyControl:SetText("Press...")
                local captureConnection = nil
                captureConnection = UserInputService.InputBegan:Connect(function(input)
                    local isKeyboard = input.UserInputType == Enum.UserInputType.Keyboard
                    if not isKeyboard or input.KeyCode == Enum.KeyCode.Unknown then
                        return
                    end
                    captureConnection:Disconnect()
                    task.defer(function()
                        self.capturingKey = false
                    end)
                    if input.KeyCode ~= Enum.KeyCode.Escape then
                        self:SetMinimizeKey(input.KeyCode)
                    end
                    keyControl:SetText(self.MinimizeKey.Name)
                end)
            end
        })
    end

    local configSection = tab:CreateSection("Config")

    controls.ConfigFile = place(configSection, "Paragraph", {
        Title = "Config file",
        Text = Library.ConfigFile()
    })

    controls.AutoSave = place(configSection, "Toggle", {
        Name = "Auto Save",
        Default = self.settings.AutoSave,
        Callback = function(state)
            self:SetAutoSave(state)
        end
    })

    local addConfigButton = function(key, doneKey, action)
        local button = nil
        button = place(configSection, "Button", {
            Name = key,
            Full = true,
            Callback = function()
                local ok = action()
                button:SetText(ok and doneKey or "Failed")
                task.delay(1.5, function()
                    if not self.destroyed then
                        button:SetText(key)
                    end
                end)
            end
        })
        return button
    end

    controls.SaveConfig = addConfigButton("Save Config", "Saved", function()
        return self:SaveConfig()
    end)
    controls.LoadConfig = addConfigButton("Load Config", "Loaded", function()
        return self:LoadConfig()
    end)
    controls.DeleteConfig = addConfigButton("Delete Config", "Deleted", function()
        return self:DeleteConfig()
    end)

    local languageSection = tab:CreateSection("Language")

    controls.Language = place(languageSection, "Dropdown", {
        Title = "Language",
        Description = "Interface language.",
        Values = Library.Locale.Languages,
        Default = Library.CurrentLanguage,
        Callback = function(value)
            self:SetLanguage(value)
        end
    })
    self.languageControl = controls.Language

    self.settingsRefresh = function()
        if controls.Side then
            controls.Side:Set(self.settings.Side)
        end
        if controls.Width then
            controls.Width:Set(self.settings.Width)
        end
        if controls.Transparency then
            controls.Transparency:Set(self.settings.Transparency)
        end
        if controls.Key then
            controls.Key:SetText(self.MinimizeKey.Name)
        end
        if controls.AutoSave then
            controls.AutoSave:Set(self.settings.AutoSave)
        end
        if controls.Language then
            controls.Language:Set(Library.CurrentLanguage)
        end
    end

    self.settingsControls = controls

    return tab
end

function Library:GetSettingsControl(name)
    return self.settingsControls and self.settingsControls[name]
end

-- // Export
return Library