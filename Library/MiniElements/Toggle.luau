-- // Toggle
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

local constructToggle = function(section, options)
    local touch = UserInputService.TouchEnabled
    local rowHeight = touch and 42 or 34
    local trackWidth = 40
    local trackHeight = 22
    local knobSize = 16
    local knobPadding = 3
    local current = options.Default == true

    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, rowHeight),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, section.Frame)

    local textHolder = create("Frame", {
        Size = UDim2.new(1, -(trackWidth + 8), 0, 0),
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

    local titleKey = resolveName(options)
    local descriptionKey = options.Description ~= nil and tostring(options.Description) or ""

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
    applyTexts()
    onLanguage(section, applyTexts)

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

    function object:Toggle()
        object:Set(not current, true)
    end

    function object:SetTitle(text)
        titleKey = tostring(text or "")
        applyTexts()
    end

    function object:SetDescription(text)
        descriptionKey = tostring(text or "")
        applyTexts()
    end

    return object
end

MiniElements.Register("Toggle", constructToggle)