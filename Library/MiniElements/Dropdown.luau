local env = getgenv and getgenv() or _G
local Library = env.MiniLibrary
local MiniElements = env.MiniElements

if type(Library) ~= "table" or type(MiniElements) ~= "table" then
    return
end

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

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
local DefaultDuration = 0.15
local PanelPadding = 6
local PanelGap = 4
local ItemGap = 2
local EmptyOrder = 1000000
local CheckIcon = "rbxassetid://10709790644"
local SelectedFade = 0.8

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
        return { Field = 38, Option = 38, Header = 22, Text = 13, Bar = 5 }
    end
    return { Field = 32, Option = 28, Header = 18, Text = 12, Bar = 3 }
end

local readDuration = function()
    local info = Tweens.Hover
    if typeof(info) == "TweenInfo" then
        return info.Time
    end
    return DefaultDuration
end

local pointInside = function(gui, position)
    local origin = gui.AbsolutePosition
    local size = gui.AbsoluteSize
    local inset = GuiService:GetGuiInset()
    local candidates = { position, position + Vector2.new(0, inset.Y) }
    for _, point in ipairs(candidates) do
        local insideX = point.X >= origin.X and point.X <= origin.X + size.X
        local insideY = point.Y >= origin.Y and point.Y <= origin.Y + size.Y
        if insideX and insideY then
            return true
        end
    end
    return false
end

local bindButtonStates = function(button, isLocked)
    local hovering = false
    button.MouseEnter:Connect(function()
        hovering = true
        if isLocked() then
            return
        end
        tween(button, Tweens.Hover, { BackgroundColor3 = Theme.LineActive })
    end)
    button.MouseLeave:Connect(function()
        hovering = false
        tween(button, Tweens.Hover, { BackgroundColor3 = Theme.Card })
    end)
    button.InputBegan:Connect(function(input)
        if isLocked() then
            return
        end
        if isPointerInput(input) then
            tween(button, Tweens.Hover, { BackgroundColor3 = PressedColor })
        end
    end)
    button.InputEnded:Connect(function(input)
        if isPointerInput(input) then
            local isTouch = input.UserInputType == Enum.UserInputType.Touch
            local color = (hovering and not isTouch) and Theme.LineActive or Theme.Card
            tween(button, Tweens.Hover, { BackgroundColor3 = color })
        end
    end)
end

local normalizeOption = function(raw)
    if raw == nil then
        return nil
    end
    if type(raw) == "table" then
        local name = raw.Name or raw.Title or raw.Text or raw.Label
        local value = raw.Value
        if name == nil and value ~= nil then
            name = tostring(value)
        end
        if name == nil then
            return nil
        end
        if value == nil then
            value = tostring(name)
        end
        local group = raw.Group or raw.Category
        return {
            Name = tostring(name),
            Value = value,
            Group = group ~= nil and tostring(group) or nil,
            Locked = raw.Locked == true or raw.Disabled == true
        }
    end
    return { Name = tostring(raw), Value = raw, Group = nil, Locked = false }
end

local buildEntries = function(list)
    local plain = {}
    local groups = {}
    local groupOrder = {}
    local seen = {}
    if type(list) == "table" then
        for _, raw in ipairs(list) do
            local entry = normalizeOption(raw)
            if entry and not seen[entry.Value] then
                seen[entry.Value] = true
                if entry.Group then
                    if not groups[entry.Group] then
                        groups[entry.Group] = {}
                        groupOrder[#groupOrder + 1] = entry.Group
                    end
                    table.insert(groups[entry.Group], entry)
                else
                    plain[#plain + 1] = entry
                end
            end
        end
    end
    local result = {}
    for _, entry in ipairs(plain) do
        result[#result + 1] = entry
    end
    for _, group in ipairs(groupOrder) do
        for _, entry in ipairs(groups[group]) do
            result[#result + 1] = entry
        end
    end
    return result
end

local constructDropdown = function(section, options)
    local window = section.Window
    local touchMode = isTouchMode()
    local dims = measure(touchMode)
    local multi = options.Multi == true or options.Multiple == true or options.MultiSelect == true
    local callback = options.Callback
    local locked = options.Locked == true
    local opened = false
    local checkIcon = type(options.CheckIcon) == "string" and options.CheckIcon or CheckIcon
    local closeOnSelect = options.CloseOnSelect
    if closeOnSelect == nil then
        closeOnSelect = not multi
    end
    local allowNone = options.AllowNone == true
    local maxSelected = tonumber(options.Max or options.MaxSelected)
    if maxSelected then
        maxSelected = math.max(1, math.floor(maxSelected))
    end
    local maxVisible = math.max(1, math.floor(tonumber(options.MaxVisible) or 6))
    local titleKey = resolveName(options)
    local descriptionKey = options.Description ~= nil and tostring(options.Description) or ""
    local placeholderKey = options.Placeholder ~= nil and tostring(options.Placeholder) or "Select..."
    local entries = buildEntries(options.Options or options.Values or options.Items or options.List)
    local selected = {}
    local rows = {}
    local headers = {}
    local animationToken = 0
    local changedSignal = newSignal()
    local openedSignal = newSignal()
    local closedSignal = newSignal()

    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, section.Frame)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0)
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
    create("UIPadding", {
        PaddingBottom = UDim.new(0, 4)
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

    local field = create("TextButton", {
        Size = UDim2.new(1, 0, 0, dims.Field),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        LayoutOrder = 2
    }, row)
    addCorner(field, 6)
    local fieldStroke = addStroke(field, Theme.Line, 1)

    local valueLabel = create("TextLabel", {
        Size = UDim2.new(1, -38, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextSecondary,
        TextSize = dims.Text,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    }, field)

    local arrow = create("Frame", {
        Size = UDim2.new(0, 12, 0, 12),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, field)
    local arrowLeft = create("Frame", {
        Size = UDim2.new(0, 8, 0, 2),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, -3, 0.5, 1),
        Rotation = 45,
        BackgroundColor3 = Theme.TextSecondary,
        BorderSizePixel = 0
    }, arrow)
    local arrowRight = create("Frame", {
        Size = UDim2.new(0, 8, 0, 2),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 3, 0.5, 1),
        Rotation = -45,
        BackgroundColor3 = Theme.TextSecondary,
        BorderSizePixel = 0
    }, arrow)
    addCorner(arrowLeft, 1)
    addCorner(arrowRight, 1)

    local holder = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        LayoutOrder = 3
    }, row)

    local panel = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, PanelGap),
        BackgroundColor3 = Theme.Card,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true
    }, holder)
    addCorner(panel, 6)
    local panelStroke = addStroke(panel, Theme.Line, 1)
    panelStroke.Transparency = 1

    local list = create("ScrollingFrame", {
        Size = UDim2.new(1, -PanelPadding * 2, 1, -PanelPadding * 2),
        Position = UDim2.new(0, PanelPadding, 0, PanelPadding),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = dims.Bar,
        ScrollBarImageColor3 = Theme.LineActive
    }, panel)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, ItemGap)
    }, list)
    create("UIPadding", {
        PaddingRight = UDim.new(0, 2)
    }, list)

    local emptyLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, dims.Option),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.TextSecondary,
        TextSize = dims.Text,
        Font = Enum.Font.Gotham,
        Visible = false,
        LayoutOrder = EmptyOrder
    }, list)

    local isLocked = function()
        return locked
    end

    bindButtonStates(field, isLocked)

    local findEntry = function(value)
        for _, entry in ipairs(entries) do
            if entry.Value == value then
                return entry
            end
        end
        for _, entry in ipairs(entries) do
            if entry.Name == value then
                return entry
            end
        end
        return nil
    end

    local countSelected = function()
        local count = 0
        for _, entry in ipairs(entries) do
            if selected[entry.Value] then
                count = count + 1
            end
        end
        return count
    end

    local readValue = function()
        if multi then
            local result = {}
            for _, entry in ipairs(entries) do
                if selected[entry.Value] then
                    result[#result + 1] = entry.Value
                end
            end
            return result
        end
        for _, entry in ipairs(entries) do
            if selected[entry.Value] then
                return entry.Value
            end
        end
        return nil
    end

    local contentHeight = function()
        local total = 0
        local count = 0
        for _, item in ipairs(headers) do
            if item.Label.Visible then
                total = total + dims.Header
                count = count + 1
            end
        end
        for _, item in ipairs(rows) do
            if item.Button.Visible then
                total = total + dims.Option
                count = count + 1
            end
        end
        if emptyLabel.Visible then
            total = total + dims.Option
            count = count + 1
        end
        if count > 1 then
            total = total + (count - 1) * ItemGap
        end
        return total
    end

    local targetHeight = function()
        local limit = maxVisible * (dims.Option + ItemGap)
        local listHeight = math.min(contentHeight(), limit)
        return PanelPadding * 2 + listHeight
    end

    local layoutPanel = function()
        list.ScrollBarThickness = dims.Bar
    end

    local updateHeight = function(instant)
        if not opened then
            return
        end
        local height = targetHeight()
        local panelGoal = UDim2.new(1, 0, 0, height)
        local holderGoal = UDim2.new(1, 0, 0, height + PanelGap)
        if instant then
            cancelTween(panel)
            cancelTween(holder)
            panel.Size = panelGoal
            holder.Size = holderGoal
            return
        end
        tween(panel, Tweens.Hover, { Size = panelGoal })
        tween(holder, Tweens.Hover, { Size = holderGoal })
    end

    local refreshField = function()
        local names = {}
        for _, entry in ipairs(entries) do
            if selected[entry.Value] then
                names[#names + 1] = translateText(section, entry.Name)
            end
        end
        if #names == 0 then
            valueLabel.Text = translateText(section, placeholderKey)
            valueLabel.TextColor3 = Theme.TextSecondary
        elseif multi and #names > 2 then
            valueLabel.Text = #names .. " " .. translateText(section, "selected")
            valueLabel.TextColor3 = Theme.TextPrimary
        else
            valueLabel.Text = table.concat(names, ", ")
            valueLabel.TextColor3 = Theme.TextPrimary
        end
    end

    local refreshRows = function()
        for _, item in ipairs(rows) do
            local isSelected = selected[item.Entry.Value] == true
            item.Selected = isSelected
            item.Label.TextColor3 = isSelected and Theme.TextPrimary or Theme.TextSecondary
            local faded = locked or item.Entry.Locked
            item.Label.TextTransparency = faded and LockedFade or 0
            local markGoal = isSelected and (faded and LockedFade or 0) or 1
            tween(item.Mark, Tweens.Hover, { ImageTransparency = markGoal })
            if not item.Hover then
                tween(item.Button, Tweens.Hover, { BackgroundTransparency = isSelected and SelectedFade or 1 })
            end
        end
    end

    local commit = function(fire)
        refreshField()
        refreshRows()
        if fire then
            local value = readValue()
            safeCall(callback, value)
            changedSignal:Fire(value)
        end
    end

    local applySelection = function(values, fire)
        table.clear(selected)
        local count = 0
        for _, value in ipairs(values) do
            local entry = findEntry(value)
            if entry and not selected[entry.Value] then
                if multi then
                    if not maxSelected or count < maxSelected then
                        selected[entry.Value] = true
                        count = count + 1
                    end
                else
                    selected[entry.Value] = true
                    break
                end
            end
        end
        commit(fire)
    end

    local close = function()
        if not opened then
            return
        end
        opened = false
        if window and window.openDropdown == object then
            window.openDropdown = nil
        end
        animationToken = animationToken + 1
        local token = animationToken
        tween(arrow, Tweens.Hover, { Rotation = 0 })
        tween(fieldStroke, Tweens.Hover, { Color = Theme.Line })
        tween(panelStroke, Tweens.Hover, { Transparency = 1 })
        tween(panel, Tweens.Hover, { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 })
        tween(holder, Tweens.Hover, { Size = UDim2.new(1, 0, 0, 0) })
        closedSignal:Fire()
        task.delay(readDuration() + 0.05, function()
            if token ~= animationToken or opened then
                return
            end
            holder.Visible = false
            panel.Size = UDim2.new(1, 0, 0, 0)
            holder.Size = UDim2.new(1, 0, 0, 0)
            panelStroke.Transparency = 1
            panel.BackgroundTransparency = 1
        end)
    end

    local open = function()
        if opened or locked then
            return
        end
        if window and window.openDropdown and window.openDropdown ~= object then
            safeCall(function()
                window.openDropdown:Close()
            end)
        end
        opened = true
        if window then
            window.openDropdown = object
        end
        animationToken = animationToken + 1
        holder.Visible = true
        layoutPanel()
        tween(arrow, Tweens.Hover, { Rotation = 180 })
        tween(fieldStroke, Tweens.Hover, { Color = Theme.LineActive })
        tween(panelStroke, Tweens.Hover, { Transparency = 0 })
        tween(panel, Tweens.Hover, { BackgroundTransparency = 0 })
        updateHeight(false)
        openedSignal:Fire()
    end

    local pick = function(entry)
        if locked or entry.Locked then
            return
        end
        local key = entry.Value
        if multi then
            if selected[key] then
                selected[key] = nil
            else
                if maxSelected and countSelected() >= maxSelected then
                    return
                end
                selected[key] = true
            end
            commit(true)
        elseif selected[key] then
            if allowNone then
                table.clear(selected)
                commit(true)
            end
        else
            table.clear(selected)
            selected[key] = true
            commit(true)
        end
        if closeOnSelect then
            close()
        end
    end

    local refreshEmpty = function()
        emptyLabel.Visible = #rows == 0
        emptyLabel.Text = translateText(section, "No options")
        updateHeight(false)
    end

    local rebuildRows = function()
        for _, item in ipairs(rows) do
            item.Button:Destroy()
        end
        for _, item in ipairs(headers) do
            item.Label:Destroy()
        end
        table.clear(rows)
        table.clear(headers)
        local order = 0
        local lastGroup = nil
        for _, entry in ipairs(entries) do
            if entry.Group ~= lastGroup then
                lastGroup = entry.Group
                if entry.Group then
                    order = order + 1
                    local headerLabel = create("TextLabel", {
                        Size = UDim2.new(1, 0, 0, dims.Header),
                        BackgroundTransparency = 1,
                        Text = string.upper(translateText(section, entry.Group)),
                        TextColor3 = Theme.TextSecondary,
                        TextSize = 10,
                        Font = Enum.Font.GothamBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        LayoutOrder = order
                    }, list)
                    create("UIPadding", {
                        PaddingLeft = UDim.new(0, 8)
                    }, headerLabel)
                    headers[#headers + 1] = { Group = entry.Group, Label = headerLabel }
                end
            end
            order = order + 1
            local button = create("TextButton", {
                Size = UDim2.new(1, 0, 0, dims.Option),
                BackgroundColor3 = Theme.LineActive,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
                LayoutOrder = order
            }, list)
            addCorner(button, 5)

            local mark = create("ImageLabel", {
                Size = UDim2.new(0, 16, 0, 16),
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Image = checkIcon,
                ImageColor3 = Theme.TextPrimary,
                ImageTransparency = 1
            }, button)

            local label = create("TextLabel", {
                Size = UDim2.new(1, -44, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
                BackgroundTransparency = 1,
                Text = translateText(section, entry.Name),
                TextColor3 = Theme.TextSecondary,
                TextSize = dims.Text,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd
            }, button)

            local item = {
                Entry = entry,
                Button = button,
                Label = label,
                Mark = mark,
                Selected = false,
                Hover = false
            }
            rows[#rows + 1] = item

            button.MouseEnter:Connect(function()
                item.Hover = true
                if not entry.Locked and not locked then
                    tween(button, Tweens.Hover, { BackgroundTransparency = 0.5 })
                end
            end)
            button.MouseLeave:Connect(function()
                item.Hover = false
                tween(button, Tweens.Hover, { BackgroundTransparency = item.Selected and SelectedFade or 1 })
            end)
            button.InputBegan:Connect(function(input)
                if entry.Locked or locked then
                    return
                end
                if isPointerInput(input) then
                    button.BackgroundColor3 = PressedColor
                    tween(button, Tweens.Hover, { BackgroundTransparency = 0 })
                end
            end)
            button.InputEnded:Connect(function(input)
                if isPointerInput(input) then
                    button.BackgroundColor3 = Theme.LineActive
                    local isTouch = input.UserInputType == Enum.UserInputType.Touch
                    local rest = item.Selected and SelectedFade or 1
                    local goal = (item.Hover and not isTouch) and 0.5 or rest
                    tween(button, Tweens.Hover, { BackgroundTransparency = goal })
                end
            end)
            button.Activated:Connect(function()
                pick(entry)
            end)
        end
        refreshRows()
        refreshEmpty()
    end

    local applyTexts = function()
        local title = titleKey == "" and "" or translateText(section, titleKey)
        local description = descriptionKey == "" and "" or translateText(section, descriptionKey)
        titleLabel.Text = title
        titleLabel.Visible = title ~= ""
        descriptionLabel.Text = description
        descriptionLabel.Visible = description ~= ""
        header.Visible = title ~= "" or description ~= ""
        emptyLabel.Text = translateText(section, "No options")
        for _, item in ipairs(rows) do
            item.Label.Text = translateText(section, item.Entry.Name)
        end
        for _, item in ipairs(headers) do
            item.Label.Text = string.upper(translateText(section, item.Group))
        end
        refreshField()
    end

    local applyLock = function()
        local fade = locked and LockedFade or 0
        titleLabel.TextTransparency = fade
        descriptionLabel.TextTransparency = fade
        field.BackgroundTransparency = fade
        valueLabel.TextTransparency = fade
        arrowLeft.BackgroundTransparency = fade
        arrowRight.BackgroundTransparency = fade
        refreshRows()
        if locked then
            close()
        end
    end

    local applyLayout = function()
        touchMode = isTouchMode()
        dims = measure(touchMode)
        field.Size = UDim2.new(1, 0, 0, dims.Field)
        valueLabel.TextSize = dims.Text
        emptyLabel.Size = UDim2.new(1, 0, 0, dims.Option)
        emptyLabel.TextSize = dims.Text
        for _, item in ipairs(rows) do
            item.Button.Size = UDim2.new(1, 0, 0, dims.Option)
            item.Label.TextSize = dims.Text
        end
        for _, item in ipairs(headers) do
            item.Label.Size = UDim2.new(1, 0, 0, dims.Header)
        end
        layoutPanel()
        updateHeight(true)
    end

    section:Connect(field.Activated, function()
        if locked then
            return
        end
        if opened then
            close()
        else
            open()
        end
    end)

    section:Connect(UserInputService.InputBegan, function(input)
        if not opened then
            return
        end
        if input.KeyCode == Enum.KeyCode.Escape then
            close()
            return
        end
        local inputType = input.UserInputType
        if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
            local position = Vector2.new(input.Position.X, input.Position.Y)
            if not pointInside(field, position) and not pointInside(panel, position) then
                close()
            end
        end
    end)

    section:Connect(UserInputService.LastInputTypeChanged, function()
        if isTouchMode() ~= touchMode then
            applyLayout()
        end
    end)

    function object:Get()
        return readValue()
    end

    function object:GetValue()
        return readValue()
    end

    function object:GetSelected()
        return readValue()
    end

    function object:GetSelectedNames()
        local names = {}
        for _, entry in ipairs(entries) do
            if selected[entry.Value] then
                names[#names + 1] = entry.Name
            end
        end
        return names
    end

    function object:GetCount()
        return countSelected()
    end

    function object:IsSelected(value)
        local entry = findEntry(value)
        return entry ~= nil and selected[entry.Value] == true
    end

    function object:IsMulti()
        return multi
    end

    function object:Set(value, fire)
        local values = {}
        if type(value) == "table" then
            for _, item in ipairs(value) do
                values[#values + 1] = item
            end
        elseif value ~= nil then
            values[1] = value
        end
        if not multi and values[1] ~= nil and not findEntry(values[1]) then
            report("Warning", "Dropdown", "Unknown option: " .. tostring(values[1]))
            return
        end
        applySelection(values, fire == true)
    end

    function object:SetValue(value, fire)
        object:Set(value, fire)
    end

    function object:Select(value, fire)
        if not multi then
            object:Set(value, fire)
            return
        end
        local values = readValue()
        local entry = findEntry(value)
        if not entry then
            report("Warning", "Dropdown", "Unknown option: " .. tostring(value))
            return
        end
        if not selected[entry.Value] then
            values[#values + 1] = entry.Value
        end
        applySelection(values, fire == true)
    end

    function object:Deselect(value, fire)
        local entry = findEntry(value)
        if not entry or not selected[entry.Value] then
            return
        end
        local values = {}
        if multi then
            for _, item in ipairs(readValue()) do
                if item ~= entry.Value then
                    values[#values + 1] = item
                end
            end
        end
        applySelection(values, fire == true)
    end

    function object:ToggleOption(value, fire)
        if object:IsSelected(value) then
            object:Deselect(value, fire)
        else
            object:Select(value, fire)
        end
    end

    function object:SelectAll(fire)
        if not multi then
            return
        end
        local values = {}
        for _, entry in ipairs(entries) do
            if not entry.Locked then
                values[#values + 1] = entry.Value
            end
        end
        applySelection(values, fire == true)
    end

    function object:ClearAll(fire)
        applySelection({}, fire == true)
    end

    function object:Clear(fire)
        applySelection({}, fire == true)
    end

    function object:Open()
        open()
    end

    function object:Close()
        close()
    end

    function object:ToggleOpen()
        if opened then
            close()
        else
            open()
        end
    end

    function object:IsOpen()
        return opened
    end

    function object:SetOptions(newOptions, keepSelection)
        local previous = readValue()
        entries = buildEntries(newOptions)
        table.clear(selected)
        rebuildRows()
        if keepSelection == false then
            commit(false)
            return
        end
        local values = {}
        if multi then
            values = previous
        elseif previous ~= nil then
            values = { previous }
        end
        applySelection(values, false)
    end

    function object:AddOption(option, index)
        local normalized = normalizeOption(option)
        if not normalized then
            report("Warning", "Dropdown", "Invalid option")
            return false
        end
        local items = {}
        for _, entry in ipairs(entries) do
            items[#items + 1] = entry
        end
        local position = math.clamp(tonumber(index) or (#items + 1), 1, #items + 1)
        table.insert(items, position, normalized)
        object:SetOptions(items, true)
        return true
    end

    function object:RemoveOption(value)
        local target = findEntry(value)
        if not target then
            return false
        end
        local items = {}
        for _, entry in ipairs(entries) do
            if entry ~= target then
                items[#items + 1] = entry
            end
        end
        object:SetOptions(items, true)
        return true
    end

    function object:ClearOptions()
        object:SetOptions({}, true)
    end

    function object:HasOption(value)
        return findEntry(value) ~= nil
    end

    function object:GetOptions()
        local items = {}
        for _, entry in ipairs(entries) do
            items[#items + 1] = {
                Name = entry.Name,
                Value = entry.Value,
                Group = entry.Group,
                Locked = entry.Locked
            }
        end
        return items
    end

    function object:SetOptionLocked(value, state)
        local entry = findEntry(value)
        if not entry then
            return false
        end
        entry.Locked = state == true
        refreshRows()
        return true
    end

    function object:SetCallback(newCallback)
        if type(newCallback) == "function" then
            callback = newCallback
        end
    end

    function object:OnChanged(listener)
        return changedSignal:Connect(listener)
    end

    function object:OnOpened(listener)
        return openedSignal:Connect(listener)
    end

    function object:OnClosed(listener)
        return closedSignal:Connect(listener)
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

    function object:SetPlaceholder(text)
        placeholderKey = tostring(text or "")
        refreshField()
    end

    function object:GetPlaceholder()
        return placeholderKey
    end

    function object:SetMax(value)
        local number = tonumber(value)
        maxSelected = number and math.max(1, math.floor(number)) or nil
        if multi then
            applySelection(readValue(), false)
        end
    end

    function object:GetMax()
        return maxSelected
    end

    function object:SetMaxVisible(value)
        local number = tonumber(value)
        if not number then
            return
        end
        maxVisible = math.max(1, math.floor(number))
        updateHeight(false)
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
        if not row.Visible then
            close()
        end
    end

    function object:Update(values)
        if type(values) ~= "table" then
            report("Warning", "Dropdown", "Update needs a table")
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
        if values.MaxVisible ~= nil then
            object:SetMaxVisible(values.MaxVisible)
        end
        if values.Max ~= nil then
            object:SetMax(values.Max)
        end
        local newOptions = values.Options or values.Values or values.Items or values.List
        if newOptions ~= nil then
            object:SetOptions(newOptions, values.KeepSelection ~= false)
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
        commit(false)
        refreshEmpty()
    end

    function object:Destroy()
        if window and window.openDropdown == object then
            window.openDropdown = nil
        end
        opened = false
        changedSignal:Clear()
        openedSignal:Clear()
        closedSignal:Clear()
        row:Destroy()
    end

    rebuildRows()
    local initial = options.Default
    if initial == nil then
        initial = options.Value
    end
    local initialValues = {}
    if type(initial) == "table" then
        for _, item in ipairs(initial) do
            initialValues[#initialValues + 1] = item
        end
    elseif initial ~= nil then
        initialValues[1] = initial
    end
    applySelection(initialValues, false)
    object:Refresh()
    onLanguage(section, function()
        applyTexts()
        refreshEmpty()
    end)

    return object
end

MiniElements.Register("Dropdown", function(section, options)
    local ok, result = pcall(constructDropdown, section, options)
    if not ok then
        warn("[Dropdown] " .. tostring(result))
        error(result, 0)
    end
    return result
end)