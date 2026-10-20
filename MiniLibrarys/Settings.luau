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
local Clipboard = setclipboard or toclipboard or (syn and syn.clipboard)

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

-- // Platform
local pick = function(touch, desktop)
    if UserInputService.TouchEnabled then
        return touch
    end
    return desktop
end

-- // Translation Helpers
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

-- // Text Binding
local bindText = function(section, object, key, config)
    config = config or {}
    local property = config.Property or "Text"
    key = tostring(key or "")
    local apply = function()
        local text = key == "" and "" or translateText(section, key)
        object[property] = text
        if config.Hide then
            object.Visible = text ~= ""
        end
    end
    apply()
    onLanguage(section, apply)
    return function(newKey)
        key = tostring(newKey or "")
        apply()
    end
end

-- // Entry Helpers
local normalizeEntries = function(list)
    local entries = {}
    for _, option in ipairs(list or {}) do
        if type(option) == "table" then
            entries[#entries + 1] = {
                Value = option.Value,
                Text = tostring(option.Text or option.Name or option.Value),
                Disabled = option.Disabled == true
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

-- // Layout Helpers
local newRow = function(parent, height)
    return create("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, parent)
end

local tightenLayout = function(section)
    local layout = section.Frame:FindFirstChildOfClass("UIListLayout")
    if layout then
        layout.Padding = UDim.new(0, 4)
    end
end

local alphaFromX = function(frame, x)
    return math.clamp((x - frame.AbsolutePosition.X) / math.max(frame.AbsoluteSize.X, 1), 0, 1)
end

local createNameLabel = function(section, parent, text, space)
    local label = createLabel(parent, "", space)
    bindText(section, label, text)
    return label
end

-- // Button Base
local createButton = function(parent, properties)
    local props = {
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextTruncate = Enum.TextTruncate.AtEnd
    }
    for key, value in pairs(properties) do
        props[key] = value
    end
    local button = create("TextButton", props, parent)
    addCorner(button, 6)
    local stroke = addStroke(button, Theme.Line, 1)
    return button, stroke
end

-- // Button Feedback
local bindFeedback = function(section, button)
    local hovered = false
    local pressed = false
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
end

-- // Drag
local bindDrag = function(section, hit, handlers)
    local page = section.Tab and section.Tab.Page
    local dragging = false
    local activeInput = nil
    local setScroll = function(state)
        if page then
            page.ScrollingEnabled = state
        end
    end
    local finish = function()
        if not dragging then
            return
        end
        dragging = false
        activeInput = nil
        setScroll(true)
        if handlers.OnEnd then
            handlers.OnEnd()
        end
    end
    section:Connect(hit.InputBegan, function(input)
        if dragging or not isPointerInput(input) then
            return
        end
        dragging = true
        activeInput = input
        setScroll(false)
        if handlers.OnStart then
            handlers.OnStart()
        end
        handlers.OnMove(input.Position.X)
    end)
    section:Connect(UserInputService.InputChanged, function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input == activeInput then
            handlers.OnMove(input.Position.X)
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
end

-- // Popup
local createPopup = function(frame, getHeight, onToggle)
    local opened = false
    local token = 0
    local popup = {}
    function popup.IsOpen()
        return opened
    end
    function popup.Resize()
        if opened then
            frame.Size = UDim2.new(1, 0, 0, getHeight())
        end
    end
    function popup.Set(state)
        opened = state
        token = token + 1
        local current = token
        if onToggle then
            onToggle(state)
        end
        if state then
            frame.Visible = true
            tween(frame, Tweens.Dropdown, { Size = UDim2.new(1, 0, 0, getHeight()) })
            return
        end
        local closing = tween(frame, Tweens.Dropdown, { Size = UDim2.new(1, 0, 0, 0) })
        closing.Completed:Connect(function()
            if current == token and not opened then
                frame.Visible = false
            end
        end)
    end
    return popup
end

-- // Header
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
    local titleLabel = createLabel(left, "", 0)
    titleLabel.Size = UDim2.new(1, 0, 0, 16)
    titleLabel.LayoutOrder = 1
    bindText(section, titleLabel, resolveName(options))
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
    bindText(section, descriptionLabel, options.Description, { Hide = true })
    return { Row = row, Title = titleLabel }
end

-- // Elements
local Elements = {}

-- // Button
Elements.Button = function(section, options)
    local full = options.Full == true
    local buttonHeight = pick(36, 30)
    local buttonWidth = pick(124, 116)
    local row = newRow(section.Frame, pick(42, 34))
    if not full then
        createNameLabel(section, row, resolveName(options), buttonWidth + 8)
    end
    local textKey = options.ButtonText
    if textKey == nil then
        textKey = full and resolveName(options) or "Run"
    end
    local button = createButton(row, {
        Size = full and UDim2.new(1, 0, 0, buttonHeight) or UDim2.new(0, buttonWidth, 0, buttonHeight),
        AnchorPoint = full and Vector2.new(0.5, 0.5) or Vector2.new(1, 0.5),
        Position = full and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(1, 0, 0.5, 0)
    })
    local setText = bindText(section, button, textKey)
    bindFeedback(section, button)
    section:Connect(button.Activated, function()
        safeCall(options.Callback)
    end)
    local object = { Frame = row, Button = button }
    function object:SetText(text)
        setText(text)
    end
    function object:GetText()
        return button.Text
    end
    return object
end

-- // Slider
Elements.Slider = function(section, options)
    local min = tonumber(options.Min) or 0
    local max = tonumber(options.Max) or 100
    local step = tonumber(options.Step) or 1
    if step <= 0 then
        step = 1
    end
    local format = options.Format
    if type(format) ~= "function" then
        format = tostring
    end
    local snap = function(value)
        value = math.floor((value - min) / step + 0.5) * step + min
        value = tonumber(string.format("%.6f", value)) or value
        return math.clamp(value, min, max)
    end
    local current = snap(tonumber(options.Default) or min)
    local rowHeight = pick(58, 48)
    local knobSize = pick(20, 14)
    local knobActive = knobSize + 4
    local trackHeight = pick(8, 6)
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
    local update = function()
        local alpha = math.clamp((current - min) / math.max(max - min, 1e-9), 0, 1)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = tostring(format(current))
    end
    local setFromX = function(x)
        local value = snap(min + alphaFromX(track, x) * (max - min))
        if value == current then
            return
        end
        current = value
        if options.Commit ~= true then
            safeCall(options.Callback, current)
        end
        update()
    end
    bindDrag(section, hit, {
        OnStart = function()
            tween(knob, Tweens.Hover, { Size = UDim2.new(0, knobActive, 0, knobActive) })
        end,
        OnMove = setFromX,
        OnEnd = function()
            tween(knob, Tweens.Hover, { Size = UDim2.new(0, knobSize, 0, knobSize) })
            if options.Commit == true then
                safeCall(options.Callback, current)
            end
            safeCall(options.OnCommit, current)
            update()
        end
    })
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
    local entries = normalizeEntries(options.Options or options.Values)
    local current = options.Default
    if current == nil and entries[1] then
        current = entries[1].Value
    end
    local count = math.max(#entries, 1)
    local width = math.max(pick(150, 136), pick(72, 64) * count)
    local row = newRow(section.Frame, pick(42, 34))
    createNameLabel(section, row, resolveName(options), width + 8)
    local holder = create("Frame", {
        Size = UDim2.new(0, width, 0, pick(36, 30)),
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
            local color = item.value == current and Theme.LineActive or Theme.Card
            tween(item.button, Tweens.Hover, { BackgroundColor3 = color })
        end
    end
    for index, entry in ipairs(entries) do
        local button = createButton(holder, {
            Size = UDim2.new(1 / count, -(4 * (count - 1)) / count, 1, 0),
            LayoutOrder = index
        })
        bindText(section, button, entry.Text)
        items[index] = { button = button, value = entry.Value }
        section:Connect(button.Activated, function()
            if current == entry.Value then
                return
            end
            current = entry.Value
            refresh()
            safeCall(options.Callback, current)
        end)
    end
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
    local boxHeight = pick(36, 30)
    local labelWidth = tonumber(options.LabelWidth) or 54
    local hasButton = options.ButtonText ~= nil
    local buttonWidth = pick(72, 64)
    local gap = 6
    local reserved = hasButton and (buttonWidth + gap) or 0
    local row = newRow(section.Frame, pick(44, 34))
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
        PlaceholderText = "",
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
    bindText(section, box, options.Placeholder, { Property = "PlaceholderText" })
    local button = nil
    local setButtonText = nil
    if hasButton then
        button = createButton(row, {
            Size = UDim2.new(0, buttonWidth, 0, boxHeight),
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0)
        })
        setButtonText = bindText(section, button, options.ButtonText)
        bindFeedback(section, button)
        section:Connect(button.Activated, function()
            safeCall(options.OnSubmit, trim(box.Text))
        end)
    end
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
        if setButtonText then
            setButtonText(text)
        end
    end
    return object
end

-- // Toggle
Elements.Toggle = function(section, options)
    local trackWidth = 40
    local trackHeight = 22
    local knobSize = 16
    local current = options.Default == true
    local row = newRow(section.Frame, pick(42, 34))
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
    bindText(section, titleLabel, options.Title or options.Name, { Hide = true })
    local setBody = bindText(
        section,
        bodyLabel,
        options.Content or options.Text or options.Description,
        { Hide = true }
    )
    local object = { Frame = row }
    function object:SetText(text)
        setBody(text)
    end
    return object
end

-- // Dropdown
Elements.Dropdown = function(section, options)
    local entries = normalizeEntries(options.Values or options.Options)
    local rowHeight = pick(44, 34)
    local selectorHeight = pick(36, 30)
    local optionHeight = pick(36, 28)
    local maxListHeight = tonumber(options.MaxHeight) or pick(190, 170)
    local selectorWidth = tonumber(options.Width) or pick(170, 156)
    local placeholderKey = tostring(options.Placeholder or "Select...")
    local current = nil
    local items = {}
    local popup = nil
    local default = options.Default
    if default ~= nil and findEntry(entries, default) then
        current = default
    elseif entries[1] then
        current = entries[1].Value
    end
    local displayText = function()
        local entry = findEntry(entries, current)
        return translateText(section, entry and entry.Text or placeholderKey)
    end
    local getListHeight = function()
        local content = #entries * optionHeight + math.max(#entries - 1, 0) * 2 + 8
        return math.min(content, maxListHeight)
    end
    tightenLayout(section)
    local header = createHeader(section, options, selectorWidth, rowHeight)
    local selector, selectorStroke = createButton(header.Row, {
        Size = UDim2.new(0, selectorWidth, 0, selectorHeight),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0)
    })
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
    popup = createPopup(list, getListHeight, function(state)
        tween(arrow, Tweens.Hover, { Rotation = state and 180 or 0 })
        tween(selectorStroke, Tweens.Hover, { Color = state and Theme.LineActive or Theme.Line })
    end)
    local refresh = function()
        selectedLabel.Text = displayText()
        for _, item in ipairs(items) do
            local selected = item.entry.Value == current
            tween(item.button, Tweens.Hover, { BackgroundTransparency = selected and 0 or 1 })
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
                if entry.Value ~= current and options.Locked ~= true then
                    tween(button, Tweens.Hover, { BackgroundTransparency = 0.6 })
                end
            end)
            button.MouseLeave:Connect(function()
                if entry.Value ~= current then
                    tween(button, Tweens.Hover, { BackgroundTransparency = 1 })
                end
            end)
            button.Activated:Connect(function()
                if options.Locked == true then
                    popup.Set(false)
                    return
                end
                local changed = current ~= entry.Value
                current = entry.Value
                refresh()
                popup.Set(false)
                if changed then
                    safeCall(options.Callback, current)
                end
            end)
        end
        popup.Resize()
        refresh()
    end
    section:Connect(selector.Activated, function()
        popup.Set(not popup.IsOpen())
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

-- // File Menu
Elements.FileMenu = function(section, options)
    local entries = normalizeEntries(options.Values or options.Options)
    local rowHeight = pick(44, 34)
    local optionHeight = pick(36, 28)
    local maxListHeight = tonumber(options.MaxHeight) or pick(190, 170)
    local tagWidth = 84
    local unavailableKey = "Unavailable"
    local current = nil
    local items = {}
    local findDefault = function()
        local default = findEntry(entries, options.Default)
        if default and not default.Disabled then
            return default.Value
        end
        for _, entry in ipairs(entries) do
            if not entry.Disabled then
                return entry.Value
            end
        end
        return nil
    end
    current = findDefault()
    local getListHeight = function()
        local content = #entries * optionHeight + math.max(#entries - 1, 0) * 2 + 8
        return math.min(content, maxListHeight)
    end
    tightenLayout(section)
    local header = createHeader(section, options, 0, rowHeight)
    local list = create("ScrollingFrame", {
        Name = "List",
        Size = UDim2.new(1, 0, 0, getListHeight()),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
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
        for _, item in ipairs(items) do
            local disabled = item.entry.Disabled
            local selected = not disabled and item.entry.Value == current
            item.tag.Text = translateText(section, unavailableKey)
            item.tag.Visible = disabled
            item.button.Text = translateText(section, item.entry.Text)
            item.button.TextColor3 = disabled and Theme.TextSecondary or Theme.TextPrimary
            tween(item.button, Tweens.Hover, { BackgroundTransparency = selected and 0 or 1 })
        end
    end
    local build = function()
        for _, item in ipairs(items) do
            item.button:Destroy()
        end
        table.clear(items)
        list.Size = UDim2.new(1, 0, 0, getListHeight())
        for index, entry in ipairs(entries) do
            local button = create("TextButton", {
                Size = UDim2.new(1, 0, 0, optionHeight),
                BackgroundColor3 = Theme.LineActive,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
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
                PaddingRight = UDim.new(0, entry.Disabled and (tagWidth + 12) or 8)
            }, button)
            local tag = create("TextLabel", {
                Size = UDim2.new(0, tagWidth, 1, 0),
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, tagWidth + 4, 0, 0),
                BackgroundTransparency = 1,
                Text = "",
                TextColor3 = Theme.TextSecondary,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Visible = false
            }, button)
            items[index] = { button = button, entry = entry, tag = tag }
            button.MouseEnter:Connect(function()
                if not entry.Disabled and entry.Value ~= current then
                    tween(button, Tweens.Hover, { BackgroundTransparency = 0.6 })
                end
            end)
            button.MouseLeave:Connect(function()
                if not entry.Disabled and entry.Value ~= current then
                    tween(button, Tweens.Hover, { BackgroundTransparency = 1 })
                end
            end)
            button.Activated:Connect(function()
                if entry.Disabled then
                    return
                end
                local changed = current ~= entry.Value
                current = entry.Value
                refresh()
                if changed then
                    safeCall(options.Callback, current)
                end
            end)
        end
        refresh()
    end
    onLanguage(section, refresh)
    build()
    local object = { Frame = header.Row, List = list }
    function object:Get()
        return current
    end
    function object:Set(value, fire)
        local entry = findEntry(entries, value)
        if not entry or entry.Disabled then
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
        local kept = findEntry(entries, current)
        if not (keepSelection ~= false and kept and not kept.Disabled) then
            current = findDefault()
        end
        build()
    end
    return object
end

-- // Color Helpers
local HueColors = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
    ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)),
    ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
    ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)),
    ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
})

local toColor = function(value)
    if typeof(value) == "Color3" then
        return value
    end
    if type(value) == "string" then
        local hex = value:gsub("^#", "")
        if #hex == 6 and hex:match("^%x+$") then
            return Color3.fromHex(hex)
        end
    end
    if type(value) == "table" and #value >= 3 then
        return Color3.fromRGB(value[1], value[2], value[3])
    end
    return nil
end

local createBar = function(section, parent, height, order, onChange)
    local bar = create("TextButton", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = order
    }, parent)
    addCorner(bar, height / 2)
    local gradient = create("UIGradient", {}, bar)
    local knob = create("Frame", {
        Size = UDim2.new(0, 6, 1, 4),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Theme.TextPrimary,
        BorderSizePixel = 0,
        ZIndex = 2
    }, bar)
    addCorner(knob, 3)
    addStroke(knob, Theme.LineActive, 1)
    bindDrag(section, bar, {
        OnMove = function(x)
            onChange(alphaFromX(bar, x))
        end
    })
    local setAlpha = function(alpha)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
    end
    return { Bar = bar, Gradient = gradient, SetAlpha = setAlpha }
end

-- // ColorPicker
Elements.ColorPicker = function(section, options)
    local rowHeight = pick(44, 34)
    local swatchWidth = 44
    local swatchHeight = pick(30, 24)
    local barHeight = pick(22, 18)
    local hexHeight = pick(34, 28)
    local panelHeight = barHeight * 3 + hexHeight + 24 + 16
    local current = toColor(options.Default) or Color3.fromRGB(255, 255, 255)
    local hue, saturation, brightness = current:ToHSV()
    tightenLayout(section)
    local header = createHeader(section, options, swatchWidth, rowHeight)
    local swatch, swatchStroke = createButton(header.Row, {
        Size = UDim2.new(0, swatchWidth, 0, swatchHeight),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        BackgroundColor3 = current
    })
    local panel = create("Frame", {
        Name = "Panel",
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Visible = false,
        ClipsDescendants = true,
        LayoutOrder = 2
    }, section.Frame)
    addCorner(panel, 6)
    addStroke(panel, Theme.Line, 1)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8)
    }, panel)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8)
    }, panel)
    local hexBox = create("TextBox", {
        Size = UDim2.new(1, 0, 0, hexHeight),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Text = "",
        PlaceholderText = "#FFFFFF",
        PlaceholderColor3 = Theme.TextSecondary,
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        LayoutOrder = 4
    }, panel)
    addCorner(hexBox, 6)
    addStroke(hexBox, Theme.Line, 1)
    local popup = createPopup(panel, function()
        return panelHeight
    end, function(state)
        tween(swatchStroke, Tweens.Hover, { Color = state and Theme.LineActive or Theme.Line })
    end)
    local hueBar = nil
    local saturationBar = nil
    local brightnessBar = nil
    local refresh = function(fire)
        current = Color3.fromHSV(hue, saturation, brightness)
        swatch.BackgroundColor3 = current
        hueBar.SetAlpha(hue)
        saturationBar.SetAlpha(saturation)
        brightnessBar.SetAlpha(brightness)
        saturationBar.Gradient.Color = ColorSequence.new(
            Color3.fromHSV(hue, 0, brightness),
            Color3.fromHSV(hue, 1, brightness)
        )
        brightnessBar.Gradient.Color = ColorSequence.new(
            Color3.fromHSV(hue, saturation, 0),
            Color3.fromHSV(hue, saturation, 1)
        )
        hexBox.Text = "#" .. current:ToHex():upper()
        if fire then
            safeCall(options.Callback, current)
        end
    end
    hueBar = createBar(section, panel, barHeight, 1, function(alpha)
        hue = alpha
        refresh(true)
    end)
    hueBar.Gradient.Color = HueColors
    saturationBar = createBar(section, panel, barHeight, 2, function(alpha)
        saturation = alpha
        refresh(true)
    end)
    brightnessBar = createBar(section, panel, barHeight, 3, function(alpha)
        brightness = alpha
        refresh(true)
    end)
    section:Connect(swatch.Activated, function()
        popup.Set(not popup.IsOpen())
    end)
    section:Connect(hexBox.FocusLost, function()
        local color = toColor(trim(hexBox.Text))
        if color then
            hue, saturation, brightness = color:ToHSV()
            refresh(true)
        else
            refresh(false)
        end
    end)
    refresh(false)
    local object = { Frame = header.Row, Panel = panel }
    function object:Get()
        return current
    end
    function object:Set(value, fire)
        local color = toColor(value)
        if not color then
            return
        end
        hue, saturation, brightness = color:ToHSV()
        refresh(fire == true)
    end
    return object
end

-- // Placement
local place = function(section, name, options)
    local holderSection = section:NewHolder(name)
    local prepared = {}
    for key, value in pairs(options) do
        prepared[key] = value
    end
    prepared.Values = prepared.Values or prepared.Options
    return Elements[name](holderSection, prepared)
end

-- // Servers
local Servers = {}

Library.Servers = Servers

local teleport = function(callback, ...)
    local ok, err = pcall(callback, TeleportService, ...)
    if not ok then
        report("Error", "Server", tostring(err))
    end
    return ok
end

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
    for _ = 1, 5 do
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
            local id = type(server) == "table" and tostring(server.id)
            if playing and maxPlayers and playing < maxPlayers and id and id ~= game.JobId then
                candidates[#candidates + 1] = id
            end
        end
        cursor = data.nextPageCursor
        if not cursor or #candidates >= 30 then
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
    return teleport(TeleportService.TeleportToPlaceInstance, game.PlaceId, jobId, LocalPlayer)
end

function Servers.Hop()
    local jobId = Servers.Find()
    if not jobId then
        report("Warning", "Server", "Nenhum servidor encontrado.")
        return false
    end
    return Servers.Join(jobId)
end

function Servers.Public()
    return teleport(TeleportService.Teleport, game.PlaceId, LocalPlayer)
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
function Library:_commitSettings(persist)
    if persist ~= false then
        self:_saveSettings()
    end
end

function Library:_layoutDrawer()
    if not self.drawerFrame then
        return
    end
    cancelTween(self.drawerFrame)
    self.drawerFrame.Size = UDim2.new(0, self.drawerWidth, 1, 0)
    self.drawerFrame.Position = self:_drawerPosition(self.isOpen)
end

function Library:SetSide(side, persist)
    self.settings.Side = side == "Left" and "Left" or "Right"
    self:_layoutDrawer()
    self:_commitSettings(persist)
end

function Library:SetWidth(value, persist)
    local limits = Library.SettingsLimits.Width
    value = math.clamp(math.floor(tonumber(value) or limits.Min), limits.Min, limits.Max)
    self.settings.Width = value
    self.drawerWidth = math.min(value, getViewport().X)
    self:_layoutDrawer()
    self:_commitSettings(persist)
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
    self:_commitSettings(persist)
end

function Library:SetMinimizeKey(keyCode, persist)
    if typeof(keyCode) ~= "EnumItem" and typeof(keyCode) ~= "Enum" then
        return
    end
    self.MinimizeKey = keyCode
    self.settings.MinimizeKey = typeof(keyCode) == "EnumItem" and keyCode.Name or tostring(keyCode)
    self:_commitSettings(persist)
end

function Library:SetAutoSave(state, persist)
    self.settings.AutoSave = state == true
    self:_commitSettings(persist)
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
    ["Nothing here yet"] = "Não tem nadinha por aqui",
    ["None"] = "Nenhum",
    ["Select..."] = "Selecione...",
    ["Run"] = "Executar",
    ["Settings"] = "Configurações",
    ["General settings and options."] = "Ajustes e definições gerais.",
    ["Server"] = "Servidor",
    ["Job ID"] = "Job ID",
    ["Paste the Job ID"] = "Cole o Job ID",
    ["Join"] = "Entrar",
    ["Copy Job ID"] = "Copiar Job ID",
    ["Copied!"] = "Copiado!",
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
    ["Config files"] = "Arquivos de configuração",
    ["Only this game's file is available."] = "Apenas o arquivo deste jogo está disponível.",
    ["Unavailable"] = "Indisponível",
    ["this game"] = "este jogo",
    ["not saved"] = "não salvo",
    ["Updated"] = "Atualizado",
    ["Save Config"] = "Salvar configuração",
    ["Load Config"] = "Carregar configuração",
    ["Delete Config"] = "Apagar configuração",
    ["Saved"] = "Salvo",
    ["Loaded"] = "Carregado",
    ["Deleted"] = "Apagado",
    ["Auto Save"] = "Salvar automaticamente",
    ["Enable"] = "Ativar",
    ["Disable"] = "Desativar",
    ["Enabled"] = "Ativado",
    ["Disabled"] = "Desativado",
    ["On"] = "Ligado",
    ["Off"] = "Desligado",
    ["Yes"] = "Sim",
    ["No"] = "Não",
    ["Save"] = "Salvar",
    ["Load"] = "Carregar",
    ["Reset"] = "Redefinir",
    ["Apply"] = "Aplicar",
    ["Cancel"] = "Cancelar",
    ["Confirm"] = "Confirmar",
    ["Close"] = "Fechar",
    ["Open"] = "Abrir",
    ["Copy"] = "Copiar",
    ["Paste"] = "Colar",
    ["Search"] = "Pesquisar",
    ["Refresh"] = "Atualizar",
    ["Start"] = "Iniciar",
    ["Stop"] = "Parar",
    ["Name"] = "Nome",
    ["Description"] = "Descrição",
    ["Value"] = "Valor",
    ["Color"] = "Cor",
    ["Speed"] = "Velocidade",
    ["Size"] = "Tamanho",
    ["Distance"] = "Distância",
    ["Player"] = "Jogador",
    ["Players"] = "Jogadores",
    ["Main"] = "Principal",
    ["Misc"] = "Diversos",
    ["Info"] = "Informações",
    ["Credits"] = "Créditos",
    ["Visuals"] = "Visuais",
    ["Combat"] = "Combate",
    ["Teleport"] = "Teletransporte"
})

-- // Translation Ignore
if type(Library.IgnoreTranslation) == "function" then
    local ignoredNames = {}
    for _, item in ipairs(Enum.KeyCode:GetEnumItems()) do
        ignoredNames[#ignoredNames + 1] = item.Name
    end
    for _, item in ipairs(Enum.UserInputType:GetEnumItems()) do
        ignoredNames[#ignoredNames + 1] = item.Name
    end
    Library:IgnoreTranslation(ignoredNames)
end

-- // Settings Helpers
local keyName = function(window)
    return window.MinimizeKey.Name or tostring(window.MinimizeKey)
end

local flashText = function(window, setText, key, text, delay)
    setText(text)
    task.delay(delay, function()
        if not window.destroyed then
            setText(key)
        end
    end)
end

local addFullButton = function(section, key, handler)
    local button = nil
    button = place(section, "Button", {
        Name = key,
        Full = true,
        Callback = function()
            handler(function(text)
                button:SetText(text)
            end, key)
        end
    })
    return button
end

local captureKey = function(window, controls)
    local keyControl = controls.Key
    if not keyControl or window.capturingKey then
        return
    end
    window.capturingKey = true
    keyControl:SetText("Press...")
    local connection = nil
    connection = UserInputService.InputBegan:Connect(function(input)
        local inputType = input.UserInputType
        local isKeyboard = inputType == Enum.UserInputType.Keyboard
        local isMouse = inputType == Enum.UserInputType.MouseButton1
            or inputType == Enum.UserInputType.MouseButton2
            or inputType == Enum.UserInputType.MouseButton3
        if not (isKeyboard or isMouse) then
            return
        end
        if isKeyboard and input.KeyCode == Enum.KeyCode.Unknown then
            return
        end
        connection:Disconnect()
        task.defer(function()
            window.capturingKey = false
        end)
        local chosen = isKeyboard and input.KeyCode or inputType
        if chosen ~= Enum.KeyCode.Escape then
            window:SetMinimizeKey(chosen)
        end
        keyControl:SetText(keyName(window))
    end)
end

-- // Config Files
local listConfigFiles = function()
    local names = {}
    if not listfiles then
        return names
    end
    local ok, paths = pcall(listfiles, Library.Folder)
    if not ok or type(paths) ~= "table" then
        return names
    end
    for _, path in ipairs(paths) do
        local name = tostring(path):match("([^/\\]+)$")
        if name and name:lower():match("%.json$") then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    return names
end

local buildFileEntries = function(window)
    local gameFile = Library.DataFile():match("([^/\\]+)$")
    local saved = false
    local entries = {}
    local texts = {}
    for _, name in ipairs(listConfigFiles()) do
        if name == gameFile then
            saved = true
        else
            entries[#entries + 1] = { Value = name, Text = name, Disabled = true }
        end
    end
    local label = gameFile .. "  (" .. window:Translate("this game")
    if not saved then
        label = label .. ", " .. window:Translate("not saved")
    end
    table.insert(entries, 1, { Value = gameFile, Text = label .. ")" })
    for _, entry in ipairs(entries) do
        texts[#texts + 1] = entry.Text
    end
    Library:IgnoreTranslation(texts)
    return entries
end

-- // Server Section
local buildServerSection = function(window, tab, controls)
    local section = tab:CreateSection("Server")
    local busy = false
    pcall(function()
        window:_connect(TeleportService.TeleportInitFailed, function(player, _, message)
            if player == LocalPlayer then
                report("Warning", "Server", tostring(message))
            end
        end)
    end)
    local runAction = function(setText, key, action)
        if busy or window.destroyed then
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
            if not window.destroyed then
                setText(key)
            end
        end)
    end
    controls.JobId = place(section, "Input", {
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
    controls.CopyJobId = place(section, "Button", {
        Name = "Job ID",
        ButtonText = "Copy Job ID",
        Callback = function()
            if not Clipboard then
                return
            end
            pcall(Clipboard, game.JobId)
            flashText(window, function(text)
                controls.CopyJobId:SetText(text)
            end, "Copy Job ID", "Copied!", 1.5)
        end
    })
    local actions = {
        { Key = "Server Hop", Name = "Hop", Action = Servers.Hop },
        { Key = "Public Server", Name = "Public", Action = Servers.Public },
        { Key = "Rejoin", Name = "Rejoin", Action = Servers.Rejoin }
    }
    for _, item in ipairs(actions) do
        controls[item.Name] = addFullButton(section, item.Key, function(setText, key)
            runAction(setText, key, item.Action)
        end)
    end
end

-- // Panel Section
local buildPanelSection = function(window, tab, controls)
    local section = tab:CreateSection("Panel Settings")
    local limits = Library.SettingsLimits
    controls.Side = place(section, "Choice", {
        Name = "Panel side",
        Options = {
            { Value = "Right", Text = "Right" },
            { Value = "Left", Text = "Left" }
        },
        Default = window.settings.Side,
        Callback = function(value)
            window:SetSide(value)
        end
    })
    controls.Width = place(section, "Slider", {
        Name = "Panel width",
        Min = limits.Width.Min,
        Max = limits.Width.Max,
        Step = limits.Width.Step,
        Default = window.settings.Width,
        Commit = true,
        Format = function(value)
            return tostring(math.floor(value)) .. "px"
        end,
        Callback = function(value)
            window:SetWidth(value)
        end
    })
    controls.Transparency = place(section, "Slider", {
        Name = "Panel transparency",
        Min = limits.Transparency.Min,
        Max = limits.Transparency.Max,
        Step = limits.Transparency.Step,
        Default = window.settings.Transparency,
        Format = function(value)
            return string.format("%d%%", math.floor(value * 100 + 0.5))
        end,
        Callback = function(value)
            window:SetTransparency(value, false)
        end,
        OnCommit = function(value)
            window:SetTransparency(value)
        end
    })
    if Library.IsMobile then
        return
    end
    controls.Key = place(section, "Button", {
        Name = "Toggle key",
        ButtonText = keyName(window),
        Callback = function()
            captureKey(window, controls)
        end
    })
end

-- // Config Section
local buildConfigSection = function(window, tab, controls)
    local section = tab:CreateSection("Config")
    local entries = buildFileEntries(window)
    controls.Files = place(section, "FileMenu", {
        Title = "Config files",
        Description = "Only this game's file is available.",
        Values = entries,
        Default = entries[1].Value
    })
    local refreshFiles = function()
        controls.Files:SetValues(buildFileEntries(window), true)
    end
    window:OnLanguageChanged(refreshFiles)
    controls.AutoSave = place(section, "Toggle", {
        Name = "Auto Save",
        Default = window.settings.AutoSave,
        Callback = function(state)
            window:SetAutoSave(state)
        end
    })
    local actions = {
        { Key = "Save Config", Done = "Saved", Name = "SaveConfig", Action = "SaveConfig" },
        { Key = "Load Config", Done = "Loaded", Name = "LoadConfig", Action = "LoadConfig" },
        { Key = "Delete Config", Done = "Deleted", Name = "DeleteConfig", Action = "DeleteConfig" }
    }
    for _, item in ipairs(actions) do
        controls[item.Name] = addFullButton(section, item.Key, function(setText, key)
            local ok = window[item.Action](window)
            flashText(window, setText, key, ok and item.Done or "Failed", 1.5)
            refreshFiles()
        end)
    end
    controls.RefreshFiles = addFullButton(section, "Refresh", function(setText, key)
        refreshFiles()
        flashText(window, setText, key, "Updated", 1.5)
    end)
end

-- // Language Section
local buildLanguageSection = function(window, tab, controls)
    local section = tab:CreateSection("Language")
    controls.Language = place(section, "Dropdown", {
        Title = "Language",
        Description = "Interface language.",
        Values = Library.Locale.Languages,
        Default = Library.CurrentLanguage,
        Callback = function(value)
            window:SetLanguage(value)
        end
    })
    window.languageControl = controls.Language
end

-- // Settings Tab
function Library:CreateSettingsTab()
    local window = self:_resolveWindow()
    if window.settingsTab then
        return window.settingsTab
    end
    local tab = window:CreateTab({
        Name = "Settings",
        Description = "General settings and options.",
        Icon = "settings"
    })
    window.settingsTab = tab
    local controls = {}
    buildServerSection(window, tab, controls)
    buildPanelSection(window, tab, controls)
    buildConfigSection(window, tab, controls)
    buildLanguageSection(window, tab, controls)
    window.settingsRefresh = function()
        local values = {
            Side = window.settings.Side,
            Width = window.settings.Width,
            Transparency = window.settings.Transparency,
            AutoSave = window.settings.AutoSave,
            Language = Library.CurrentLanguage
        }
        for name, value in pairs(values) do
            if controls[name] then
                controls[name]:Set(value)
            end
        end
        if controls.Key then
            controls.Key:SetText(keyName(window))
        end
    end
    window.settingsControls = controls
    return tab
end

function Library:GetSettingsControl(name)
    return self.settingsControls and self.settingsControls[name]
end

-- // Export
return Library