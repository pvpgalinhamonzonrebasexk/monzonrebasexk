-- // Base
local env = getgenv and getgenv() or _G
local Library = env.MiniLibrary
local MiniElements = env.MiniElements

if type(Library) ~= "table" or type(MiniElements) ~= "table" then
    print("MiniLibrary e MiniElements nao encontrados")
    return
end

local UserInputService = game:GetService("UserInputService")

local Theme = Library.Theme
local Tweens = Library.Tweens
local tween = Library.Tween
local create = Library.Create
local addCorner = Library.AddCorner
local resolveName = Library.ResolveName

local WhiteColor = Color3.fromRGB(255, 255, 255)
local KnobOnColor = Color3.fromRGB(25, 25, 28)
local LockedFade = 0.5
local KeyWidth = 54

-- // Erros
local run = function(fn, ...)
    if type(fn) ~= "function" then
        return
    end
    local ok, err = pcall(fn, ...)
    if not ok then
        print(tostring(err))
    end
end

-- // Idioma
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

-- // Dispositivo
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
        return { Row = 46, TrackW = 46, TrackH = 24, Knob = 18, Key = 26, Text = 13, Small = 11 }
    end
    return { Row = 40, TrackW = 38, TrackH = 20, Knob = 14, Key = 22, Text = 12, Small = 10 }
end

-- // Teclas
local KeyNames = {
    LeftShift = "LShift",
    RightShift = "RShift",
    LeftControl = "LCtrl",
    RightControl = "RCtrl",
    LeftAlt = "LAlt",
    RightAlt = "RAlt",
    Return = "Enter",
    Zero = "0",
    One = "1",
    Two = "2",
    Three = "3",
    Four = "4",
    Five = "5",
    Six = "6",
    Seven = "7",
    Eight = "8",
    Nine = "9"
}

local keyLabel = function(key)
    return KeyNames[key.Name] or key.Name
end

local resolveKey = function(value)
    if value == nil or value == false then
        return nil
    end
    if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
        return value
    end
    if type(value) == "string" then
        local ok, item = pcall(function()
            return Enum.KeyCode[value]
        end)
        if ok and item then
            return item
        end
    end
    print("Tecla invalida " .. tostring(value))
    return nil
end

-- // Toggle
local constructToggle = function(section, options)
    options = type(options) == "table" and options or {}
    local touchMode = isTouchMode()
    local dims = measure(touchMode)
    local callback = options.Callback
    local keybindCallback = options.KeybindCallback
    local locked = options.Locked == true
    local state = options.Default == true or options.Value == true
    local nameKey = resolveName(options)
    local descriptionKey = options.Description ~= nil and tostring(options.Description) or ""
    local showKeybind = options.ShowKeybind ~= false
    local keybind = resolveKey(options.Keybind)
    local listening = false

    -- // Visual
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, section.Frame)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 4)
    }, row)

    local object = { Frame = row }

    local card = create("Frame", {
        Size = UDim2.new(1, 0, 0, dims.Row),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0
    }, row)
    addCorner(card, 6)
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

    local textBlock = create("Frame", {
        Size = UDim2.new(1, -60, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1
    }, card)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2)
    }, textBlock)

    local titleLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextPrimary,
        TextSize = dims.Text,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1
    }, textBlock)

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

    local keyButton = create("TextButton", {
        Size = UDim2.new(0, KeyWidth, 0, dims.Key),
        BackgroundColor3 = Theme.Line,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        TextColor3 = Theme.TextSecondary,
        TextSize = dims.Small,
        Font = Enum.Font.GothamMedium,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 2
    }, card)
    addCorner(keyButton, 5)

    local track = create("TextButton", {
        Size = UDim2.new(0, dims.TrackW, 0, dims.TrackH),
        BackgroundColor3 = Theme.Line,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = 3
    }, card)
    addCorner(track, 99)

    local knob = create("Frame", {
        Size = UDim2.new(0, dims.Knob, 0, dims.Knob),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        BackgroundColor3 = Theme.TextSecondary,
        BorderSizePixel = 0
    }, track)
    addCorner(knob, 99)

    -- // Estado
    local applyState = function(animate)
        local trackColor = state and WhiteColor or Theme.Line
        local knobColor = state and KnobOnColor or Theme.TextSecondary
        local knobPosition = state and UDim2.new(0, dims.TrackW - dims.Knob - 3, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        if animate then
            tween(track, Tweens.Hover, { BackgroundColor3 = trackColor })
            tween(knob, Tweens.Hover, { BackgroundColor3 = knobColor, Position = knobPosition })
        else
            track.BackgroundColor3 = trackColor
            knob.BackgroundColor3 = knobColor
            knob.Position = knobPosition
        end
    end

    local setState = function(value, silent)
        value = value == true
        if value == state then
            return
        end
        state = value
        applyState(true)
        if not silent then
            run(callback, state)
        end
    end

    -- // Keybind
    local refreshKey = function()
        if listening then
            keyButton.Text = "..."
            keyButton.BackgroundColor3 = Theme.LineActive
            keyButton.TextColor3 = Theme.TextPrimary
            return
        end
        keyButton.Text = keybind and keyLabel(keybind) or translateText(section, "None")
        keyButton.BackgroundColor3 = Theme.Line
        keyButton.TextColor3 = Theme.TextSecondary
    end

    local keyVisible = function()
        return showKeybind and not touchMode
    end

    -- // Layout
    local applyLayout = function()
        touchMode = isTouchMode()
        dims = measure(touchMode)
        local visible = keyVisible()
        if not visible then
            listening = false
        end
        keyButton.Visible = visible
        keyButton.Size = UDim2.new(0, KeyWidth, 0, dims.Key)
        keyButton.TextSize = dims.Small
        track.Size = UDim2.new(0, dims.TrackW, 0, dims.TrackH)
        knob.Size = UDim2.new(0, dims.Knob, 0, dims.Knob)
        titleLabel.TextSize = dims.Text
        descriptionLabel.TextSize = dims.Small
        card.Size = UDim2.new(1, 0, 0, dims.Row)
        local offset = 20 + 10 + dims.TrackW + (visible and (KeyWidth + 10) or 0)
        textBlock.Size = UDim2.new(1, -offset, 0, 0)
        applyState(false)
        refreshKey()
    end

    local applyTexts = function()
        local title = nameKey == "" and "" or translateText(section, nameKey)
        local description = descriptionKey == "" and "" or translateText(section, descriptionKey)
        titleLabel.Text = title
        titleLabel.Visible = title ~= ""
        descriptionLabel.Text = description
        descriptionLabel.Visible = description ~= ""
        refreshKey()
    end

    local applyLock = function()
        local fade = locked and LockedFade or 0
        card.BackgroundTransparency = fade
        titleLabel.TextTransparency = fade
        descriptionLabel.TextTransparency = fade
        track.BackgroundTransparency = fade
        knob.BackgroundTransparency = fade
        keyButton.BackgroundTransparency = fade
        keyButton.TextTransparency = fade
        if locked then
            listening = false
            refreshKey()
        end
    end

    -- // Eventos
    section:Connect(track.Activated, function()
        if locked then
            return
        end
        setState(not state)
    end)

    section:Connect(keyButton.Activated, function()
        if locked or not keyVisible() then
            return
        end
        listening = not listening
        refreshKey()
    end)

    section:Connect(UserInputService.InputBegan, function(input, processed)
        if listening then
            if input.UserInputType ~= Enum.UserInputType.Keyboard then
                return
            end
            if input.KeyCode == Enum.KeyCode.Escape then
                listening = false
                refreshKey()
                return
            end
            if input.KeyCode == Enum.KeyCode.Backspace then
                keybind = nil
            else
                keybind = input.KeyCode
            end
            listening = false
            refreshKey()
            run(keybindCallback, keybind and keybind.Name or nil)
            return
        end
        if locked or processed or not keybind then
            return
        end
        if UserInputService:GetFocusedTextBox() then
            return
        end
        if input.KeyCode == keybind then
            setState(not state)
        end
    end)

    section:Connect(UserInputService.LastInputTypeChanged, function()
        if isTouchMode() ~= touchMode then
            applyLayout()
        end
    end)

    -- // API
    function object:SetValue(value, silent)
        setState(value, silent == true)
    end

    function object:GetValue()
        return state
    end

    function object:Toggle()
        if locked then
            return
        end
        setState(not state)
    end

    function object:SetKeybind(value)
        keybind = resolveKey(value)
        refreshKey()
    end

    function object:GetKeybind()
        return keybind and keybind.Name or nil
    end

    function object:ClearKeybind()
        keybind = nil
        refreshKey()
    end

    function object:SetShowKeybind(value)
        showKeybind = value == true
        applyLayout()
    end

    function object:SetName(text)
        nameKey = tostring(text or "")
        applyTexts()
    end

    function object:GetName()
        return nameKey
    end

    function object:SetDescription(text)
        descriptionKey = tostring(text or "")
        applyTexts()
    end

    function object:SetCallback(newCallback)
        if type(newCallback) == "function" then
            callback = newCallback
        end
    end

    function object:SetKeybindCallback(newCallback)
        if type(newCallback) == "function" then
            keybindCallback = newCallback
        end
    end

    function object:SetLocked(value)
        locked = value == true
        applyLock()
    end

    function object:IsLocked()
        return locked
    end

    function object:SetVisible(value)
        row.Visible = value == true
        if not row.Visible then
            listening = false
            refreshKey()
        end
    end

    function object:Update(values)
        if type(values) ~= "table" then
            print("Update precisa de uma tabela")
            return false
        end
        local newName = values.Name or values.Title
        if newName ~= nil then
            nameKey = tostring(newName)
        end
        if values.Description ~= nil then
            descriptionKey = tostring(values.Description)
        end
        if type(values.Callback) == "function" then
            callback = values.Callback
        end
        if type(values.KeybindCallback) == "function" then
            keybindCallback = values.KeybindCallback
        end
        if values.Keybind ~= nil then
            keybind = resolveKey(values.Keybind)
        end
        if values.ShowKeybind ~= nil then
            showKeybind = values.ShowKeybind == true
        end
        if values.Locked ~= nil then
            locked = values.Locked == true
        end
        if values.Visible ~= nil then
            object:SetVisible(values.Visible)
        end
        applyLayout()
        applyTexts()
        applyLock()
        local newValue = values.Value
        if newValue == nil then
            newValue = values.Default
        end
        if newValue ~= nil then
            setState(newValue, values.Silent == true)
        end
        return true
    end

    function object:Refresh()
        applyLayout()
        applyTexts()
        applyLock()
    end

    function object:Destroy()
        listening = false
        row:Destroy()
    end

    applyLayout()
    applyTexts()
    applyLock()
    onLanguage(section, applyTexts)

    task.defer(function()
        if state then
            run(callback, state)
        end
    end)

    return object
end

-- // Registro
MiniElements.Register("Toggle", function(section, options)
    local ok, result = pcall(constructToggle, section, options)
    if not ok then
        print(tostring(result))
        return nil
    end
    return result
end)