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
    local buttonHeight = touch and 42 or 34
    local verticalPadding = math.floor((buttonHeight - 16) / 2)
    local callback = options.Callback
    local locked = options.Locked == true
    local hovered = false
    local pressed = false
    local titleKey = resolveName(options)
    local descriptionKey = options.Description ~= nil and tostring(options.Description) or ""
    local clickSignal = newSignal()

    local button = create("TextButton", {
        Size = UDim2.new(1, 0, 0, buttonHeight),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = ""
    }, section.Frame)
    addCorner(button, 6)
    addStroke(button, Theme.Line, 1)
    create("UIPadding", {
        PaddingTop = UDim.new(0, verticalPadding),
        PaddingBottom = UDim.new(0, verticalPadding),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10)
    }, button)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2)
    }, button)

    local titleLabel = createLabel(button, translateText(section, titleKey), 0)
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
    }, button)

    local object = { Frame = button, Button = button }

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
        button.BackgroundTransparency = fade
        titleLabel.TextTransparency = fade
        descriptionLabel.TextTransparency = fade
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
        button.Visible = state == true
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
        button:Destroy()
    end

    -- // Initialize
    object:Refresh()
    onLanguage(section, applyTexts)

    return object
end

-- // Register
MiniElements.Register("Button", constructButton)