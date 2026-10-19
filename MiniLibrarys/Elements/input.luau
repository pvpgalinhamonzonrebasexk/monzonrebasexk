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
local create = Library.Create
local addCorner = Library.AddCorner
local addStroke = Library.AddStroke
local createLabel = Library.CreateLabel
local resolveName = Library.ResolveName
local safeCall = Library.SafeCall
local report = Library.Report

local LockedFade = 0.5

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
        return { Field = 38, Text = 13 }
    end
    return { Field = 32, Text = 12 }
end

local formatValue = function(value)
    if value == nil then
        return ""
    end
    if type(value) == "number" and value % 1 == 0 and math.abs(value) < 1e15 then
        return string.format("%d", value)
    end
    return tostring(value)
end

local constructInput = function(section, options)
    options = type(options) == "table" and options or {}
    local touchMode = isTouchMode()
    local dims = measure(touchMode)
    local callback = options.Callback
    local locked = options.Locked == true
    local numeric = options.Numeric == true or string.lower(tostring(options.Type or "")) == "number"
    local integer = options.Integer == true
    local minValue = tonumber(options.Min)
    local maxValue = tonumber(options.Max)
    local maxLength = tonumber(options.MaxLength)
    if maxLength then
        maxLength = math.max(1, math.floor(maxLength))
    end
    local live = options.Live == true
    local clearOnFocus = options.ClearOnFocus == true
    local titleKey = resolveName(options)
    local descriptionKey = options.Description ~= nil and tostring(options.Description) or ""
    local placeholderKey = options.Placeholder ~= nil and tostring(options.Placeholder) or "Type here..."
    local value = nil
    local hovering = false
    local changedSignal = newSignal()
    local submitSignal = newSignal()
    local focusedSignal = newSignal()
    local blurredSignal = newSignal()

    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, section.Frame)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4)
    }, row)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6)
    }, row)

    local object = { Frame = row }

    local header = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1
    }, row)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2)
    }, header)

    local titleLabel = createLabel(header, translateText(section, titleKey), 0)
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
    }, header)

    local box = create("TextBox", {
        Size = UDim2.new(1, 0, 0, dims.Field),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = translateText(section, placeholderKey),
        PlaceholderColor3 = Theme.TextSecondary,
        TextColor3 = Theme.TextPrimary,
        TextSize = dims.Text,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = clearOnFocus,
        TextEditable = not locked,
        LayoutOrder = 2
    }, row)
    addCorner(box, 6)
    local boxStroke = addStroke(box, Theme.Line, 1)
    create("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10)
    }, box)

    local sanitize = function(text)
        text = tostring(text or "")
        if numeric then
            text = (text:gsub("[^%d%.%-]", ""))
            if integer then
                text = (text:gsub("%.", ""))
            end
        end
        if maxLength and #text > maxLength then
            text = text:sub(1, maxLength)
        end
        return text
    end

    local parse = function(text)
        if not numeric then
            return text
        end
        local number = tonumber(text)
        if number == nil then
            return nil
        end
        if integer then
            number = math.floor(number + 0.5)
        end
        if minValue then
            number = math.max(minValue, number)
        end
        if maxValue then
            number = math.min(maxValue, number)
        end
        return number
    end

    local fireChange = function()
        safeCall(callback, value)
        changedSignal:Fire(value)
    end

    local applyText = function(text, fire)
        local clean = sanitize(text)
        local parsed = parse(clean)
        if numeric and parsed == nil then
            value = nil
            box.Text = ""
        else
            value = parsed
            box.Text = formatValue(parsed)
        end
        if fire then
            fireChange()
        end
    end

    local applyTexts = function()
        local title = titleKey == "" and "" or translateText(section, titleKey)
        local description = descriptionKey == "" and "" or translateText(section, descriptionKey)
        titleLabel.Text = title
        titleLabel.Visible = title ~= ""
        descriptionLabel.Text = description
        descriptionLabel.Visible = description ~= ""
        header.Visible = title ~= "" or description ~= ""
        box.PlaceholderText = translateText(section, placeholderKey)
    end

    local applyLock = function()
        local fade = locked and LockedFade or 0
        titleLabel.TextTransparency = fade
        descriptionLabel.TextTransparency = fade
        box.BackgroundTransparency = fade
        box.TextTransparency = fade
        box.PlaceholderColor3 = Theme.TextSecondary
        box.TextEditable = not locked
        if locked and box:IsFocused() then
            box:ReleaseFocus()
        end
    end

    local applyLayout = function()
        touchMode = isTouchMode()
        dims = measure(touchMode)
        box.Size = UDim2.new(1, 0, 0, dims.Field)
        box.TextSize = dims.Text
    end

    local initial = options.Default
    if initial == nil then
        initial = options.Value
    end
    if initial ~= nil then
        applyText(tostring(initial), false)
    end

    box:GetPropertyChangedSignal("Text"):Connect(function()
        local clean = sanitize(box.Text)
        if clean ~= box.Text then
            box.Text = clean
            return
        end
        if not live then
            return
        end
        local parsed = parse(clean)
        if numeric and parsed == nil then
            return
        end
        if parsed ~= value then
            value = parsed
            fireChange()
        end
    end)

    box.Focused:Connect(function()
        tween(boxStroke, Tweens.Hover, { Color = Theme.LineActive })
        focusedSignal:Fire()
    end)

    box.FocusLost:Connect(function(enterPressed)
        tween(boxStroke, Tweens.Hover, { Color = hovering and Theme.LineActive or Theme.Line })
        local clean = sanitize(box.Text)
        local parsed = parse(clean)
        if numeric and parsed == nil then
            box.Text = formatValue(value)
        else
            local changed = parsed ~= value
            value = parsed
            box.Text = formatValue(parsed)
            if changed then
                fireChange()
            end
        end
        if enterPressed then
            submitSignal:Fire(value)
        end
        blurredSignal:Fire(enterPressed)
    end)

    box.MouseEnter:Connect(function()
        hovering = true
        if not locked and not box:IsFocused() then
            tween(boxStroke, Tweens.Hover, { Color = Theme.LineActive })
        end
    end)

    box.MouseLeave:Connect(function()
        hovering = false
        if not box:IsFocused() then
            tween(boxStroke, Tweens.Hover, { Color = Theme.Line })
        end
    end)

    section:Connect(UserInputService.LastInputTypeChanged, function()
        if isTouchMode() ~= touchMode then
            applyLayout()
        end
    end)

    function object:Get()
        return value
    end

    function object:GetValue()
        return value
    end

    function object:GetText()
        return box.Text
    end

    function object:Set(newValue, fire)
        if newValue == nil then
            object:Clear(fire)
            return
        end
        if numeric and tonumber(newValue) == nil then
            report("Warning", "Input", "Set expects a number")
            return
        end
        applyText(tostring(newValue), fire == true)
    end

    function object:SetValue(newValue, fire)
        object:Set(newValue, fire)
    end

    function object:Clear(fire)
        value = numeric and nil or ""
        box.Text = ""
        if fire == true then
            fireChange()
        end
    end

    function object:Focus()
        if not locked then
            box:CaptureFocus()
        end
    end

    function object:Unfocus()
        box:ReleaseFocus()
    end

    function object:IsFocused()
        return box:IsFocused()
    end

    function object:SetPlaceholder(text)
        placeholderKey = tostring(text or "")
        applyTexts()
    end

    function object:GetPlaceholder()
        return placeholderKey
    end

    function object:SetNumeric(state)
        numeric = state == true
        applyText(box.Text, false)
    end

    function object:IsNumeric()
        return numeric
    end

    function object:SetMin(newValue)
        minValue = tonumber(newValue)
        if numeric then
            applyText(box.Text, false)
        end
    end

    function object:GetMin()
        return minValue
    end

    function object:SetMax(newValue)
        maxValue = tonumber(newValue)
        if numeric then
            applyText(box.Text, false)
        end
    end

    function object:GetMax()
        return maxValue
    end

    function object:SetMaxLength(newValue)
        local number = tonumber(newValue)
        maxLength = number and math.max(1, math.floor(number)) or nil
        applyText(box.Text, false)
    end

    function object:GetMaxLength()
        return maxLength
    end

    function object:SetLive(state)
        live = state == true
    end

    function object:SetCallback(newCallback)
        if type(newCallback) == "function" then
            callback = newCallback
        end
    end

    function object:OnChanged(listener)
        return changedSignal:Connect(listener)
    end

    function object:OnSubmit(listener)
        return submitSignal:Connect(listener)
    end

    function object:OnFocused(listener)
        return focusedSignal:Connect(listener)
    end

    function object:OnBlurred(listener)
        return blurredSignal:Connect(listener)
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
        if not row.Visible and box:IsFocused() then
            box:ReleaseFocus()
        end
    end

    function object:Update(values)
        if type(values) ~= "table" then
            report("Warning", "Input", "Update needs a table")
            return false
        end
        local newName = values.Name or values.Title
        if newName ~= nil then
            titleKey = tostring(newName)
        end
        if values.Description ~= nil then
            descriptionKey = tostring(values.Description)
        end
        if values.Placeholder ~= nil then
            placeholderKey = tostring(values.Placeholder)
        end
        if type(values.Callback) == "function" then
            callback = values.Callback
        end
        if values.Numeric ~= nil then
            numeric = values.Numeric == true
        end
        if values.Integer ~= nil then
            integer = values.Integer == true
        end
        if values.Min ~= nil then
            minValue = tonumber(values.Min)
        end
        if values.Max ~= nil then
            maxValue = tonumber(values.Max)
        end
        if values.MaxLength ~= nil then
            local number = tonumber(values.MaxLength)
            maxLength = number and math.max(1, math.floor(number)) or nil
        end
        if values.Live ~= nil then
            live = values.Live == true
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
        else
            applyText(box.Text, false)
        end
        return true
    end

    function object:Refresh()
        applyLayout()
        applyTexts()
        applyLock()
    end

    function object:Destroy()
        changedSignal:Clear()
        submitSignal:Clear()
        focusedSignal:Clear()
        blurredSignal:Clear()
        row:Destroy()
    end

    object:Refresh()
    onLanguage(section, function()
        applyTexts()
    end)

    return object
end

MiniElements.Register("Input", function(section, options)
    local ok, result = pcall(constructInput, section, options)
    if not ok then
        warn("[Input] " .. tostring(result))
        error(result, 0)
    end
    return result
end)