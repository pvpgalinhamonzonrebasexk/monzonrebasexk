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

local LockedFade = 0.5
local TouchIntentDistance = 8
local KnobGrowScale = 1.25
local SliderTween = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

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

-- // Slider
local constructSlider = function(section, options)
    local touch = UserInputService.TouchEnabled
    local headerHeight = 20
    local hitHeight = touch and 36 or 26
    local knobSize = touch and 20 or 14
    local trackHeight = touch and 8 or 6
    local minValue = tonumber(options.Min) or 0
    local maxValue = tonumber(options.Max) or 100
    local step = tonumber(options.Step) or 1
    local format = type(options.Format) == "function" and options.Format or tostring
    local commitMode = options.Commit == true
    local callback = options.Callback
    local locked = options.Locked == true
    local page = section.Tab and section.Tab.Page
    local titleKey = resolveName(options)
    local descriptionKey = options.Description ~= nil and tostring(options.Description) or ""
    local changedSignal = newSignal()
    local commitSignal = newSignal()
    local dragging = false
    local pending = false
    local activeInput = nil
    local startPosition = Vector2.zero
    local current = 0

    if minValue >= maxValue then
        report("Warning", "Slider", "Invalid range, using 0-100")
        minValue = 0
        maxValue = 100
    end
    if step <= 0 then
        step = 1
    end
    commitSignal:Connect(options.OnCommit)

    local snap = function(value)
        value = math.floor((value - minValue) / step + 0.5) * step + minValue
        value = tonumber(string.format("%.6f", value)) or value
        return math.clamp(value, minValue, maxValue)
    end

    current = snap(tonumber(options.Default) or minValue)

    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, section.Frame)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 2)
    }, row)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2)
    }, row)

    local header = create("Frame", {
        Size = UDim2.new(1, 0, 0, headerHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1
    }, row)

    local titleLabel = createLabel(header, translateText(section, titleKey), 74)

    local valueLabel = create("TextLabel", {
        Size = UDim2.new(0, 70, 1, 0),
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextSecondary,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Right
    }, header)

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
    }, row)

    local hit = create("TextButton", {
        Size = UDim2.new(1, 0, 0, hitHeight),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = 3
    }, row)

    local track = create("Frame", {
        Size = UDim2.new(1, -knobSize, 0, trackHeight),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, knobSize / 2, 0.5, 0),
        BackgroundColor3 = Theme.Line,
        BorderSizePixel = 0
    }, hit)
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
    addCorner(knob, knobSize)
    addStroke(knob, Theme.LineActive, 1)
    local knobScale = create("UIScale", { Scale = 1 }, knob)

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
        valueLabel.TextTransparency = fade
        descriptionLabel.TextTransparency = fade
        track.BackgroundTransparency = fade
        fill.BackgroundTransparency = fade
        knob.BackgroundTransparency = fade
    end

    -- // State
    local update = function(instant)
        local range = math.max(maxValue - minValue, 1e-9)
        local alpha = math.clamp((current - minValue) / range, 0, 1)
        local fillSize = UDim2.new(alpha, 0, 1, 0)
        local knobPosition = UDim2.new(alpha, 0, 0.5, 0)
        if instant then
            cancelTween(fill)
            cancelTween(knob)
            fill.Size = fillSize
            knob.Position = knobPosition
        else
            tween(fill, SliderTween, { Size = fillSize })
            tween(knob, SliderTween, { Position = knobPosition })
        end
        local ok, text = pcall(format, current)
        valueLabel.Text = ok and tostring(text) or tostring(current)
    end

    local fireChange = function()
        safeCall(callback, current)
        changedSignal:Fire(current)
    end

    -- // Drag
    local setScroll = function(state)
        if page and page.Parent then
            page.ScrollingEnabled = state
        end
    end

    local setKnobScale = function(scale)
        tween(knobScale, Tweens.Hover, { Scale = scale })
    end

    local setFromX = function(positionX)
        local alpha = math.clamp((positionX - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local value = snap(minValue + alpha * (maxValue - minValue))
        if value == current then
            return
        end
        current = value
        update(false)
        if not commitMode then
            fireChange()
        end
    end

    local beginDrag = function(input)
        dragging = true
        pending = false
        activeInput = input
        setScroll(false)
        setKnobScale(KnobGrowScale)
        setFromX(input.Position.X)
    end

    local finishDrag = function()
        local wasDragging = dragging
        dragging = false
        pending = false
        activeInput = nil
        if not wasDragging then
            return
        end
        setScroll(true)
        setKnobScale(1)
        if commitMode then
            fireChange()
        end
        commitSignal:Fire(current)
    end

    section:Connect(hit.InputBegan, function(input)
        if locked or dragging or pending or not isPointerInput(input) then
            return
        end
        if input.UserInputType == Enum.UserInputType.Touch then
            pending = true
            activeInput = input
            startPosition = Vector2.new(input.Position.X, input.Position.Y)
            return
        end
        beginDrag(input)
    end)

    section:Connect(UserInputService.InputChanged, function(input)
        if not activeInput then
            return
        end
        if pending then
            if input ~= activeInput then
                return
            end
            local delta = Vector2.new(input.Position.X, input.Position.Y) - startPosition
            local horizontal = math.abs(delta.X)
            local vertical = math.abs(delta.Y)
            if horizontal >= TouchIntentDistance and horizontal > vertical then
                beginDrag(activeInput)
            elseif vertical >= TouchIntentDistance then
                pending = false
                activeInput = nil
            end
            return
        end
        if not dragging then
            return
        end
        local isTouchDrag = activeInput.UserInputType == Enum.UserInputType.Touch
        if isTouchDrag then
            if input == activeInput then
                setFromX(input.Position.X)
            end
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end
        if not UserInputService:IsMouseButtonPressed(activeInput.UserInputType) then
            finishDrag()
            return
        end
        setFromX(input.Position.X)
    end)

    section:Connect(UserInputService.InputEnded, function(input)
        if not activeInput then
            return
        end
        local sameInput = input == activeInput
        local sameMouse = activeInput.UserInputType ~= Enum.UserInputType.Touch
            and input.UserInputType == activeInput.UserInputType
        local ended = activeInput.UserInputState == Enum.UserInputState.End
        if not (sameInput or sameMouse or ended) then
            return
        end
        if pending then
            dragging = true
            setFromX(input.Position.X)
        end
        finishDrag()
    end)

    -- // Slider API
    function object:Get()
        return current
    end

    function object:GetValue()
        return current
    end

    function object:Set(value, fire)
        current = snap(tonumber(value) or current)
        update(false)
        if fire == true then
            fireChange()
        end
    end

    function object:SetValue(value, fire)
        object:Set(value, fire)
    end

    function object:Reset(fire)
        object:Set(tonumber(options.Default) or minValue, fire)
    end

    -- // Range API
    function object:SetRange(newMin, newMax)
        newMin = tonumber(newMin)
        newMax = tonumber(newMax)
        if not newMin or not newMax or newMin >= newMax then
            report("Warning", "Slider", "Invalid range")
            return false
        end
        minValue = newMin
        maxValue = newMax
        current = snap(current)
        update(false)
        return true
    end

    function object:SetMin(value)
        return object:SetRange(value, maxValue)
    end

    function object:SetMax(value)
        return object:SetRange(minValue, value)
    end

    function object:GetRange()
        return minValue, maxValue
    end

    function object:SetStep(value)
        value = tonumber(value)
        if not value or value <= 0 then
            report("Warning", "Slider", "Invalid step")
            return false
        end
        step = value
        current = snap(current)
        update(false)
        return true
    end

    function object:GetStep()
        return step
    end

    function object:SetFormat(newFormat)
        if type(newFormat) ~= "function" then
            report("Warning", "Slider", "Format needs a function")
            return false
        end
        format = newFormat
        update(false)
        return true
    end

    -- // Events API
    function object:SetCallback(newCallback)
        if type(newCallback) == "function" then
            callback = newCallback
        end
    end

    function object:SetCommitMode(state)
        commitMode = state == true
    end

    function object:OnChanged(listener)
        return changedSignal:Connect(listener)
    end

    function object:OnCommit(listener)
        return commitSignal:Connect(listener)
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

    -- // Lock API
    function object:SetLocked(state)
        locked = state == true
        if locked then
            finishDrag()
        end
        applyLock()
    end

    function object:IsLocked()
        return locked
    end

    function object:SetVisible(state)
        row.Visible = state == true
        if not row.Visible then
            finishDrag()
        end
    end

    -- // Update API
    function object:Update(values)
        if type(values) ~= "table" then
            report("Warning", "Slider", "Update needs a table")
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
        if values.Commit ~= nil then
            commitMode = values.Commit == true
        end
        if values.Min ~= nil or values.Max ~= nil then
            object:SetRange(values.Min or minValue, values.Max or maxValue)
        end
        if values.Step ~= nil then
            object:SetStep(values.Step)
        end
        if values.Format ~= nil then
            object:SetFormat(values.Format)
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
        applyTexts()
        applyLock()
        update(true)
    end

    function object:Destroy()
        finishDrag()
        changedSignal:Clear()
        commitSignal:Clear()
        row:Destroy()
    end

    -- // Initialize
    object:Refresh()
    onLanguage(section, applyTexts)

    return object
end

-- // Register
MiniElements.Register("Slider", constructSlider)