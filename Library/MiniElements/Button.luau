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

-- // Button
local constructButton = function(section, options)
    local touch = UserInputService.TouchEnabled
    local full = options.Full == true
    local rowHeight = touch and 42 or 34
    local buttonHeight = touch and 36 or 30
    local buttonWidth = touch and 124 or 116
    local callback = options.Callback
    local locked = options.Locked == true
    local hovered = false
    local pressed = false
    local titleKey = resolveName(options)
    local descriptionKey = options.Description ~= nil and tostring(options.Description) or ""
    local explicitText = options.ButtonText ~= nil and tostring(options.ButtonText) or nil
    local clickSignal = newSignal()
    local titleLabel = nil
    local descriptionLabel = nil

    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, rowHeight),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, section.Frame)

    if not full then
        local textHolder = create("Frame", {
            Size = UDim2.new(1, -(buttonWidth + 8), 0, 0),
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
        titleLabel = createLabel(textHolder, translateText(section, titleKey), 0)
        titleLabel.Size = UDim2.new(1, 0, 0, 16)
        titleLabel.LayoutOrder = 1
        descriptionLabel = create("TextLabel", {
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
    end

    local button = create("TextButton", {
        Size = full and UDim2.new(1, 0, 0, buttonHeight) or UDim2.new(0, buttonWidth, 0, buttonHeight),
        AnchorPoint = full and Vector2.new(0, 0.5) or Vector2.new(1, 0.5),
        Position = full and UDim2.new(0, 0, 0.5, 0) or UDim2.new(1, 0, 0.5, 0),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextTruncate = Enum.TextTruncate.AtEnd
    }, row)
    addCorner(button, 6)
    addStroke(button, Theme.Line, 1)

    local object = { Frame = row, Button = button }

    -- // Name
    local resolveButtonText = function()
        if explicitText ~= nil then
            return explicitText
        end
        return full and titleKey or "Run"
    end

    local applyTexts = function()
        if titleLabel then
            titleLabel.Text = translateText(section, titleKey)
            local description = descriptionKey == "" and "" or translateText(section, descriptionKey)
            descriptionLabel.Text = description
            descriptionLabel.Visible = description ~= ""
        end
        button.Text = translateText(section, resolveButtonText())
    end

    -- // Lock
    local applyLock = function()
        local fade = locked and LockedFade or 0
        button.BackgroundTransparency = fade
        button.TextTransparency = fade
        if titleLabel then
            titleLabel.TextTransparency = fade
            descriptionLabel.TextTransparency = fade
        end
    end

    -- // State
    local refreshColor = function()
        if not button.Parent then
            return
        end
        local color = Theme.Card
        if pressed then
            color = PressedColor
        elseif hovered then
            color = Theme.LineActive
        end
        tween(button, Tweens.Hover, { BackgroundColor3 = color })
    end

    local trigger = function()
        safeCall(callback)
        clickSignal:Fire()
    end

    -- // Button Input
    section:Connect(button.MouseEnter, function()
        if locked then
            return
        end
        hovered = true
        refreshColor()
    end)

    section:Connect(button.MouseLeave, function()
        hovered = false
        pressed = false
        refreshColor()
    end)

    section:Connect(button.InputBegan, function(input)
        if locked or not isPointerInput(input) then
            return
        end
        pressed = true
        refreshColor()
    end)

    section:Connect(button.InputEnded, function(input)
        if not isPointerInput(input) then
            return
        end
        pressed = false
        if input.UserInputType == Enum.UserInputType.Touch then
            hovered = false
        end
        refreshColor()
    end)

    section:Connect(button.Activated, function()
        if locked then
            return
        end
        trigger()
    end)

    -- // Button API
    function object:Click()
        trigger()
    end

    function object:SetText(text)
        explicitText = tostring(text or "")
        applyTexts()
    end

    function object:GetText()
        return button.Text
    end

    -- // Events API
    function object:SetCallback(newCallback)
        if type(newCallback) == "function" then
            callback = newCallback
        end
    end

    function object:OnClick(listener)
        return clickSignal:Connect(listener)
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
        hovered = false
        pressed = false
        applyLock()
        refreshColor()
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
            report("Warning", "Button", "Update needs a table")
            return false
        end
        local newName = values.Name or values.Title
        if newName ~= nil then
            titleKey = tostring(newName)
        end
        if values.Description ~= nil then
            descriptionKey = tostring(values.Description)
        end
        if values.ButtonText ~= nil then
            explicitText = tostring(values.ButtonText)
        end
        if type(values.Callback) == "function" then
            callback = values.Callback
        end
        if values.Locked ~= nil then
            object:SetLocked(values.Locked)
        end
        if values.Visible ~= nil then
            object:SetVisible(values.Visible)
        end
        applyTexts()
        return true
    end

    function object:Refresh()
        applyTexts()
        applyLock()
        refreshColor()
    end

    function object:Destroy()
        clickSignal:Clear()
        row:Destroy()
    end

    -- // Initialize
    object:Refresh()
    onLanguage(section, applyTexts)

    return object
end

-- // Register
MiniElements.Register("Button", constructButton)