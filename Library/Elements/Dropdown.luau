-- // Dropdown
Elements.Register("Dropdown", function(section, options)
    options = type(options) == "table" and options or {}

    local COLORS = {
        TextActive = Color3.fromRGB(255, 255, 255),
        TextInactive = Color3.fromRGB(105, 105, 115),
        TextDisabled = Color3.fromRGB(60, 60, 68),
        FieldBg = Color3.fromRGB(22, 22, 22),
        FieldBorder = Color3.fromRGB(38, 38, 38),
        FieldBorderHover = Color3.fromRGB(70, 70, 80),
        RowBg = Color3.fromRGB(20, 20, 20),
        RowHover = Color3.fromRGB(30, 30, 30),
        RowSelected = Color3.fromRGB(36, 36, 36),
        OverlayBg = Color3.fromRGB(20, 20, 20),
        OverlayBorder = Color3.fromRGB(38, 38, 38),
        SearchBg = Color3.fromRGB(26, 26, 26),
        SearchBorder = Color3.fromRGB(40, 40, 40),
        SearchPlaceholder = Color3.fromRGB(90, 90, 100),
        DescText = Color3.fromRGB(100, 100, 110),
        TitleText = Color3.fromRGB(255, 255, 255),
        Icon = Color3.fromRGB(100, 100, 110),
        IconActive = Color3.fromRGB(255, 255, 255),
        ScrollBar = Color3.fromRGB(80, 80, 90),
    }

    local tweenService = TweenService or game:GetService("TweenService")
    local userInputService = UserInputService or game:GetService("UserInputService")
    local runService = game:GetService("RunService")
    local fontRegular = FONT or Enum.Font.SourceSans
    local fontTitle = FONT or Enum.Font.SourceSansSemibold
    local checkImage = (ICONS and ICONS.assets and ICONS.assets["lucide-check"]) or "rbxassetid://10709790644"
    local searchImage = (ICONS and ICONS.assets and ICONS.assets["lucide-search"]) or "rbxassetid://10734943674"
    local clearImage = (ICONS and ICONS.assets and ICONS.assets["lucide-x"]) or "rbxassetid://10747384394"
    local chevronImage = "rbxassetid://10709790948"

    local MOBILE = userInputService.TouchEnabled and not userInputService.KeyboardEnabled

    local TITLE_SIZE = MOBILE and 13 or 12
    local DESC_SIZE = MOBILE and 11 or 10
    local LABEL_SIZE = MOBILE and 12 or 11
    local ROW_H = MOBILE and 46 or 40
    local FIELD_W = MOBILE and 140 or 150
    local FIELD_MIN_W = 96
    local FIELD_H = MOBILE and 32 or 26
    local OPT_H = MOBILE and 38 or 30
    local SEARCH_H = MOBILE and 32 or 26
    local SEARCH_AREA = SEARCH_H + 10
    local MAX_H = MOBILE and 270 or 230
    local CHECK_SIZE = 12
    local GAP = 4
    local ANIM_T = 0.12
    local WORD_BREAK = 20
    local Z = 900

    local TI_FAST = TweenInfo.new(0.1)
    local TI_ROW = TweenInfo.new(0.09)
    local TI_HOVER = TweenInfo.new(0.07)
    local TI_OPEN = TweenInfo.new(ANIM_T, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local TI_CLOSE = TweenInfo.new(ANIM_T, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    local TI_ICON = TweenInfo.new(ANIM_T)

    local connections = {}
    local rowConnections = {}
    local destroyed = false
    local opening = false
    local animating = false
    local followConn
    local closeTween
    local closeTweenConn
    local openTween
    local origin = Vector2.new(0, 0)
    local originMeasured = false
    local fieldHover = false
    local openedAt = 0

    local function connect(signal, fn)
        local conn = signal:Connect(fn)
        table.insert(connections, conn)
        return conn
    end

    local function warnf(msg)
        pcall(function()
            Notify({ Title = "Ecohub | Dropdown", Description = msg, Duration = 5 })
        end)
    end

    local function breakWords(text, maxRun)
        text = tostring(text or "")
        local lines = {}
        for line in (text .. "\n"):gmatch("(.-)\n") do
            local r = {}
            for w in line:gmatch("%S+") do
                while #w > maxRun do
                    table.insert(r, w:sub(1, maxRun))
                    w = w:sub(maxRun + 1)
                end
                table.insert(r, w)
            end
            table.insert(lines, table.concat(r, " "))
        end
        return table.concat(lines, "\n")
    end

    local function tw(obj, info, props)
        if destroyed or not obj or not obj.Parent then return end
        pcall(function()
            tweenService:Create(obj, info, props):Play()
        end)
    end

    local function isPointerInput(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
    end

    local function usingTouch()
        return userInputService:GetLastInputType() == Enum.UserInputType.Touch
    end

    local function isInside(guiObject, pos)
        local p = guiObject.AbsolutePosition
        local s = guiObject.AbsoluteSize
        return pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
    end

    local title = tostring(options.title or options.Name or "Dropdown")
    local desc = tostring(options.description or "")
    local values = type(options.values or options.Options) == "table" and (options.values or options.Options) or {}
    local multi = options.multi == true
    local disabled = options.disabled == true
    local callback = options.callback or options.Callback
    local placeholder = tostring(options.placeholder or "Select...")
    local allowDeselect = options.allowDeselect ~= false

    if type(callback) ~= "function" then
        callback = function() end
    end

    local hasDesc = desc ~= ""

    local data = {
        disabled = disabled,
        expanded = false,
    }

    local function hasValue(v)
        return table.find(values, v) ~= nil
    end

    if multi then
        data.value = {}
        if type(options.default) == "table" then
            for _, v in ipairs(options.default) do
                if hasValue(v) then data.value[v] = true end
            end
        end
    else
        data.value = nil
        if options.default ~= nil and hasValue(options.default) then
            data.value = options.default
        end
    end

    local screenGui = section.frame:FindFirstAncestorWhichIsA("ScreenGui")

    local container = Instance.new("Frame")
    container.Name = title .. "_Dropdown"
    container.Size = UDim2.new(1, 0, 0, ROW_H)
    container.BackgroundTransparency = 1
    container.ClipsDescendants = false
    container.Parent = section.frame

    local headerRow = Instance.new("Frame")
    headerRow.Name = "Header"
    headerRow.Size = UDim2.new(1, 0, 0, ROW_H)
    headerRow.BackgroundTransparency = 1
    headerRow.Parent = container

    local textSide = Instance.new("Frame")
    textSide.Name = "TextSide"
    textSide.Size = UDim2.new(1, -(FIELD_W + 16), 1, 0)
    textSide.BackgroundTransparency = 1
    textSide.Parent = headerRow

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = disabled and COLORS.TextDisabled or COLORS.TitleText
    titleLabel.TextSize = TITLE_SIZE
    titleLabel.Font = fontTitle
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextYAlignment = Enum.TextYAlignment.Center
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.Parent = textSide

    local descLabel

    local function layoutText()
        if descLabel then
            titleLabel.Size = UDim2.new(1, 0, 0, 16)
            titleLabel.Position = UDim2.new(0, 0, 0, 2)
        else
            titleLabel.Size = UDim2.new(1, 0, 1, 0)
            titleLabel.Position = UDim2.new(0, 0, 0, 0)
        end
    end

    local function createDescription(text)
        descLabel = Instance.new("TextLabel")
        descLabel.Name = "Desc"
        descLabel.Size = UDim2.new(1, 0, 0, 0)
        descLabel.Position = UDim2.new(0, 0, 0, 18)
        descLabel.AutomaticSize = Enum.AutomaticSize.Y
        descLabel.BackgroundTransparency = 1
        descLabel.Text = breakWords(text, WORD_BREAK)
        descLabel.TextColor3 = COLORS.DescText
        descLabel.TextSize = DESC_SIZE
        descLabel.Font = fontRegular
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.TextWrapped = true
        descLabel.LineHeight = 1.1
        descLabel.Parent = textSide
    end

    if hasDesc then
        createDescription(desc)
    end

    layoutText()

    local field = Instance.new("TextButton")
    field.Name = "Field"
    field.Size = UDim2.new(0, FIELD_W, 0, FIELD_H)
    field.Position = UDim2.new(1, 0, 0.5, 0)
    field.AnchorPoint = Vector2.new(1, 0.5)
    field.BackgroundColor3 = COLORS.FieldBg
    field.BorderSizePixel = 0
    field.Text = ""
    field.AutoButtonColor = false
    field.Selectable = false
    field.Active = not disabled
    field.Parent = headerRow

    local fieldCorner = Instance.new("UICorner")
    fieldCorner.CornerRadius = UDim.new(0, 6)
    fieldCorner.Parent = field

    local fStroke = Instance.new("UIStroke")
    fStroke.Color = COLORS.FieldBorder
    fStroke.Thickness = 1
    fStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    fStroke.Parent = field

    local fieldText = Instance.new("TextLabel")
    fieldText.Name = "FieldText"
    fieldText.Size = UDim2.new(1, -28, 1, 0)
    fieldText.Position = UDim2.new(0, 9, 0, 0)
    fieldText.BackgroundTransparency = 1
    fieldText.Text = placeholder
    fieldText.TextColor3 = COLORS.TextInactive
    fieldText.TextSize = LABEL_SIZE
    fieldText.Font = fontRegular
    fieldText.TextXAlignment = Enum.TextXAlignment.Left
    fieldText.TextTruncate = Enum.TextTruncate.AtEnd
    fieldText.Parent = field

    local fieldIcon = Instance.new("ImageLabel")
    fieldIcon.Name = "Icon"
    fieldIcon.Size = UDim2.new(0, 11, 0, 11)
    fieldIcon.Position = UDim2.new(1, -8, 0.5, 0)
    fieldIcon.AnchorPoint = Vector2.new(1, 0.5)
    fieldIcon.BackgroundTransparency = 1
    fieldIcon.Image = chevronImage
    fieldIcon.ImageColor3 = COLORS.Icon
    fieldIcon.Parent = field

    local function applyWidth()
        if destroyed then return end
        local width = container.AbsoluteSize.X
        local fieldW = FIELD_W
        if width > 0 then
            fieldW = math.clamp(math.floor(width * 0.5), FIELD_MIN_W, FIELD_W)
        end
        field.Size = UDim2.new(0, fieldW, 0, FIELD_H)
        textSide.Size = UDim2.new(1, -(fieldW + 16), 1, 0)
    end

    connect(container:GetPropertyChangedSignal("AbsoluteSize"), applyWidth)
    applyWidth()

    local overlay = Instance.new("Frame")
    overlay.Name = title .. "_Overlay"
    overlay.BackgroundColor3 = COLORS.OverlayBg
    overlay.BorderSizePixel = 0
    overlay.Size = UDim2.fromOffset(0, 0)
    overlay.Visible = false
    overlay.Active = true
    overlay.ZIndex = Z
    overlay.ClipsDescendants = true
    overlay.Parent = screenGui or container

    local overlayCorner = Instance.new("UICorner")
    overlayCorner.CornerRadius = UDim.new(0, 8)
    overlayCorner.Parent = overlay

    local oStroke = Instance.new("UIStroke")
    oStroke.Color = COLORS.OverlayBorder
    oStroke.Thickness = 1
    oStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    oStroke.Parent = overlay

    local searchFrame = Instance.new("Frame")
    searchFrame.Name = "Search"
    searchFrame.Size = UDim2.new(1, -10, 0, SEARCH_H)
    searchFrame.Position = UDim2.new(0, 5, 0, 5)
    searchFrame.BackgroundColor3 = COLORS.SearchBg
    searchFrame.BorderSizePixel = 0
    searchFrame.ZIndex = Z + 1
    searchFrame.Parent = overlay

    local searchCorner = Instance.new("UICorner")
    searchCorner.CornerRadius = UDim.new(0, 6)
    searchCorner.Parent = searchFrame

    local sStroke = Instance.new("UIStroke")
    sStroke.Color = COLORS.SearchBorder
    sStroke.Thickness = 1
    sStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    sStroke.Parent = searchFrame

    local searchIcon = Instance.new("ImageLabel")
    searchIcon.Name = "Icon"
    searchIcon.Size = UDim2.new(0, 13, 0, 13)
    searchIcon.Position = UDim2.new(0, 8, 0.5, 0)
    searchIcon.AnchorPoint = Vector2.new(0, 0.5)
    searchIcon.BackgroundTransparency = 1
    searchIcon.Image = searchImage
    searchIcon.ImageColor3 = COLORS.Icon
    searchIcon.ZIndex = Z + 2
    searchIcon.Parent = searchFrame

    local searchBox = Instance.new("TextBox")
    searchBox.Name = "Input"
    searchBox.Size = UDim2.new(1, -52, 1, 0)
    searchBox.Position = UDim2.new(0, 28, 0, 0)
    searchBox.BackgroundTransparency = 1
    searchBox.Text = ""
    searchBox.PlaceholderText = "Search..."
    searchBox.PlaceholderColor3 = COLORS.SearchPlaceholder
    searchBox.TextColor3 = COLORS.TextActive
    searchBox.TextSize = LABEL_SIZE
    searchBox.Font = fontRegular
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.TextTruncate = Enum.TextTruncate.AtEnd
    searchBox.ClearTextOnFocus = false
    searchBox.ZIndex = Z + 2
    searchBox.Parent = searchFrame

    local clearBtn = Instance.new("ImageButton")
    clearBtn.Name = "Clear"
    clearBtn.Size = UDim2.new(0, 14, 0, 14)
    clearBtn.Position = UDim2.new(1, -8, 0.5, 0)
    clearBtn.AnchorPoint = Vector2.new(1, 0.5)
    clearBtn.BackgroundTransparency = 1
    clearBtn.Image = clearImage
    clearBtn.ImageColor3 = COLORS.Icon
    clearBtn.AutoButtonColor = false
    clearBtn.Selectable = false
    clearBtn.Visible = false
    clearBtn.ZIndex = Z + 3
    clearBtn.Parent = searchFrame

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Scroll"
    scroll.Size = UDim2.new(1, -4, 1, -(SEARCH_AREA + 2))
    scroll.Position = UDim2.new(0, 2, 0, SEARCH_AREA)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = MOBILE and 3 or 2
    scroll.ScrollBarImageColor3 = COLORS.ScrollBar
    scroll.ScrollBarImageTransparency = 0
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ZIndex = Z
    scroll.Parent = overlay

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 1)
    listLayout.Parent = scroll

    local listPad = Instance.new("UIPadding")
    listPad.PaddingTop = UDim.new(0, 1)
    listPad.PaddingBottom = UDim.new(0, 3)
    listPad.PaddingLeft = UDim.new(0, 3)
    listPad.PaddingRight = UDim.new(0, 5)
    listPad.Parent = scroll

    local emptyLabel = Instance.new("TextLabel")
    emptyLabel.Name = "Empty"
    emptyLabel.Size = UDim2.new(1, 0, 0, OPT_H)
    emptyLabel.Position = UDim2.new(0, 0, 0, SEARCH_AREA)
    emptyLabel.BackgroundTransparency = 1
    emptyLabel.Text = "No results found"
    emptyLabel.TextColor3 = COLORS.TextInactive
    emptyLabel.TextSize = LABEL_SIZE
    emptyLabel.Font = fontRegular
    emptyLabel.Visible = false
    emptyLabel.ZIndex = Z + 1
    emptyLabel.Parent = overlay

    local optRows = {}

    local function isSelected(value)
        if multi then
            return data.value[value] == true
        end
        return data.value == value
    end

    local function hasSelection()
        if multi then
            return next(data.value) ~= nil
        end
        return data.value ~= nil
    end

    local function getSelectedList()
        local sel = {}
        for _, v in ipairs(values) do
            if data.value[v] then
                table.insert(sel, v)
            end
        end
        return sel
    end

    local function getOutput()
        if multi then
            return getSelectedList()
        end
        return data.value
    end

    local function getDisplayText()
        if multi then
            local sel = getSelectedList()
            if #sel == 0 then return placeholder end
            local names = {}
            for i, v in ipairs(sel) do
                names[i] = tostring(v)
            end
            return table.concat(names, ", ")
        end
        if data.value == nil then return placeholder end
        return tostring(data.value)
    end

    local function updateField(animate)
        local col
        if data.disabled then
            col = COLORS.TextDisabled
        elseif hasSelection() then
            col = COLORS.TextActive
        else
            col = COLORS.TextInactive
        end
        fieldText.Text = getDisplayText()
        titleLabel.TextColor3 = data.disabled and COLORS.TextDisabled or COLORS.TitleText
        if animate then
            tw(fieldText, TI_FAST, { TextColor3 = col })
        else
            fieldText.TextColor3 = col
        end
    end

    local function updateFieldBorder()
        if destroyed then return end
        local hot = (fieldHover or data.expanded) and not data.disabled
        tw(fStroke, TI_HOVER, { Color = hot and COLORS.FieldBorderHover or COLORS.FieldBorder })
    end

    local function updateRow(row, animate)
        local sel = isSelected(row.value)
        local bg = sel and COLORS.RowSelected or COLORS.RowBg
        local tc = sel and COLORS.TextActive or (data.disabled and COLORS.TextDisabled or COLORS.TextInactive)
        local checkT = sel and 0 or 1
        if animate then
            tw(row.frame, TI_ROW, { BackgroundColor3 = bg })
            tw(row.label, TI_ROW, { TextColor3 = tc })
            tw(row.check, TI_ROW, { ImageTransparency = checkT })
        else
            row.frame.BackgroundColor3 = bg
            row.label.TextColor3 = tc
            row.check.ImageTransparency = checkT
        end
    end

    local function fireCallback()
        local ok, err = pcall(callback, getOutput())
        if not ok then warnf("callback: " .. tostring(err)) end
    end

    local function applyFilter()
        if destroyed then return end
        local query = searchBox.Text:lower()
        local shown = 0
        for _, row in ipairs(optRows) do
            local match = query == "" or string.find(tostring(row.value):lower(), query, 1, true) ~= nil
            row.frame.Visible = match
            if match then
                shown = shown + 1
            end
        end
        emptyLabel.Visible = shown == 0
        clearBtn.Visible = query ~= ""
        scroll.CanvasPosition = Vector2.new(0, 0)
    end

    local function getScreenH()
        local cam = workspace.CurrentCamera
        return cam and cam.ViewportSize.Y or 600
    end

    local function getContentH()
        local listH = emptyLabel.Visible and (OPT_H + 6) or (listLayout.AbsoluteContentSize.Y + 6)
        return SEARCH_AREA + listH + 2
    end

    local function computePlacement()
        local fPos = field.AbsolutePosition
        local fSize = field.AbsoluteSize
        local screenH = getScreenH()
        local y = fPos.Y + fSize.Y + GAP
        local avail = math.floor(screenH - y - 8)
        local h = math.min(getContentH(), MAX_H, math.floor(screenH * 0.5))
        h = math.max(math.min(h, avail), math.min(SEARCH_AREA + OPT_H + 8, h))
        return fPos, fSize, h, y
    end

    local function stopFollow()
        if followConn then
            followConn:Disconnect()
            followConn = nil
        end
    end

    local function cancelTweens()
        animating = false
        if openTween then
            openTween:Cancel()
            openTween = nil
        end
        if closeTweenConn then
            closeTweenConn:Disconnect()
            closeTweenConn = nil
        end
        if closeTween then
            closeTween:Cancel()
            closeTween = nil
        end
    end

    local closeOverlay

    local function reposition()
        if destroyed or not data.expanded then return end
        local cam = workspace.CurrentCamera
        local fPos, fSize, h, y = computePlacement()
        if cam then
            local vp = cam.ViewportSize
            if fPos.Y + fSize.Y < 0 or fPos.Y > vp.Y or fPos.X + fSize.X < 0 or fPos.X > vp.X then
                closeOverlay(true)
                return
            end
        end
        overlay.Position = UDim2.fromOffset(fPos.X - origin.X, y - origin.Y)
        if not animating then
            overlay.Size = UDim2.fromOffset(fSize.X, h)
        end
    end

    local function startFollow()
        stopFollow()
        followConn = runService.RenderStepped:Connect(reposition)
    end

    closeOverlay = function(instant)
        if not data.expanded then return end
        data.expanded = false
        stopFollow()
        cancelTweens()
        searchBox:ReleaseFocus()
        tw(fieldIcon, TI_ICON, { Rotation = 0, ImageColor3 = COLORS.Icon })
        updateFieldBorder()

        if instant then
            overlay.Visible = false
            overlay.Size = UDim2.fromOffset(0, 0)
            return
        end

        local fSize = field.AbsoluteSize
        closeTween = tweenService:Create(overlay, TI_CLOSE, { Size = UDim2.fromOffset(fSize.X, 0) })
        closeTweenConn = closeTween.Completed:Connect(function()
            if not data.expanded and not destroyed then
                overlay.Visible = false
            end
            if closeTweenConn then
                closeTweenConn:Disconnect()
                closeTweenConn = nil
            end
        end)
        closeTween:Play()
    end

    local function selectValue(value)
        if destroyed or data.disabled then return end
        if multi then
            if data.value[value] then
                data.value[value] = nil
            else
                data.value[value] = true
            end
        else
            if data.value == value then
                if not allowDeselect then
                    closeOverlay(false)
                    return
                end
                data.value = nil
            else
                data.value = value
            end
        end
        for _, row in ipairs(optRows) do updateRow(row, true) end
        updateField(true)
        fireCallback()
        if not multi then closeOverlay(false) end
    end

    local function clearRowConnections()
        for _, conn in ipairs(rowConnections) do
            conn:Disconnect()
        end
        table.clear(rowConnections)
    end

    local function buildOptions()
        clearRowConnections()
        for _, row in ipairs(optRows) do
            if row.frame then row.frame:Destroy() end
        end
        optRows = {}

        for i, value in ipairs(values) do
            local optFrame = Instance.new("Frame")
            optFrame.Name = "Opt_" .. i
            optFrame.Size = UDim2.new(1, 0, 0, OPT_H)
            optFrame.BackgroundColor3 = COLORS.RowBg
            optFrame.BorderSizePixel = 0
            optFrame.LayoutOrder = i
            optFrame.ZIndex = Z

            local optCorner = Instance.new("UICorner")
            optCorner.CornerRadius = UDim.new(0, 5)
            optCorner.Parent = optFrame

            optFrame.Parent = scroll

            local optLabel = Instance.new("TextLabel")
            optLabel.Name = "Label"
            optLabel.Size = UDim2.new(1, -(CHECK_SIZE + 26), 1, 0)
            optLabel.Position = UDim2.new(0, 10, 0, 0)
            optLabel.BackgroundTransparency = 1
            optLabel.Text = tostring(value)
            optLabel.TextColor3 = COLORS.TextInactive
            optLabel.TextSize = LABEL_SIZE
            optLabel.Font = fontRegular
            optLabel.TextXAlignment = Enum.TextXAlignment.Left
            optLabel.TextYAlignment = Enum.TextYAlignment.Center
            optLabel.TextTruncate = Enum.TextTruncate.AtEnd
            optLabel.ZIndex = Z + 1
            optLabel.Parent = optFrame

            local optCheck = Instance.new("ImageLabel")
            optCheck.Name = "Check"
            optCheck.Size = UDim2.new(0, CHECK_SIZE, 0, CHECK_SIZE)
            optCheck.Position = UDim2.new(1, -10, 0.5, 0)
            optCheck.AnchorPoint = Vector2.new(1, 0.5)
            optCheck.BackgroundTransparency = 1
            optCheck.Image = checkImage
            optCheck.ImageColor3 = COLORS.IconActive
            optCheck.ImageTransparency = 1
            optCheck.ZIndex = Z + 1
            optCheck.Parent = optFrame

            local btn = Instance.new("TextButton")
            btn.Name = "Btn"
            btn.Size = UDim2.new(1, 0, 1, 0)
            btn.BackgroundTransparency = 1
            btn.Text = ""
            btn.AutoButtonColor = false
            btn.Selectable = false
            btn.ZIndex = Z + 2
            btn.Parent = optFrame

            local row = { frame = optFrame, label = optLabel, check = optCheck, value = value }
            table.insert(optRows, row)

            updateRow(row, false)

            table.insert(rowConnections, btn.MouseEnter:Connect(function()
                if usingTouch() then return end
                if not isSelected(value) and not data.disabled then
                    tw(optFrame, TI_HOVER, { BackgroundColor3 = COLORS.RowHover })
                end
            end))
            table.insert(rowConnections, btn.MouseLeave:Connect(function()
                if not isSelected(value) then
                    tw(optFrame, TI_HOVER, { BackgroundColor3 = COLORS.RowBg })
                end
            end))
            table.insert(rowConnections, btn.Activated:Connect(function()
                selectValue(value)
            end))
        end

        applyFilter()
    end

    local function openOverlay()
        if destroyed or data.disabled or data.expanded or opening or #values == 0 then return end
        data.expanded = true
        opening = true
        openedAt = os.clock()
        cancelTweens()
        updateFieldBorder()

        if searchBox.Text ~= "" then
            searchBox.Text = ""
        end
        applyFilter()

        task.defer(function()
            if destroyed or not data.expanded then
                opening = false
                return
            end

            if not originMeasured or not screenGui then
                overlay.AnchorPoint = Vector2.new(0, 0)
                overlay.Size = UDim2.fromOffset(1, 1)
                overlay.Position = UDim2.fromOffset(0, 0)
                overlay.Visible = true
                runService.RenderStepped:Wait()
                if destroyed then
                    opening = false
                    return
                end
                origin = overlay.AbsolutePosition
                originMeasured = true
                if not data.expanded then
                    overlay.Visible = false
                    overlay.Size = UDim2.fromOffset(0, 0)
                    opening = false
                    return
                end
            end

            local fPos, fSize, h, y = computePlacement()

            overlay.Size = UDim2.fromOffset(fSize.X, 0)
            overlay.Position = UDim2.fromOffset(fPos.X - origin.X, y - origin.Y)
            overlay.Visible = true

            tw(fieldIcon, TI_ICON, { Rotation = 180, ImageColor3 = COLORS.IconActive })

            animating = true
            local currentTween = tweenService:Create(overlay, TI_OPEN, {
                Size = UDim2.fromOffset(fSize.X, h),
            })
            openTween = currentTween
            currentTween.Completed:Connect(function()
                if openTween == currentTween then
                    animating = false
                end
            end)
            currentTween:Play()

            startFollow()
            opening = false

            if not MOBILE then
                task.defer(function()
                    if not destroyed and data.expanded then
                        searchBox:CaptureFocus()
                    end
                end)
            end
        end)
    end

    connect(field.Activated, function()
        if data.expanded then
            closeOverlay(false)
        else
            openOverlay()
        end
    end)

    connect(field.MouseEnter, function()
        if usingTouch() then return end
        fieldHover = true
        updateFieldBorder()
    end)

    connect(field.MouseLeave, function()
        fieldHover = false
        updateFieldBorder()
    end)

    connect(searchBox:GetPropertyChangedSignal("Text"), applyFilter)

    connect(searchBox.Focused, function()
        tw(sStroke, TI_HOVER, { Color = COLORS.FieldBorderHover })
        tw(searchIcon, TI_HOVER, { ImageColor3 = COLORS.IconActive })
    end)

    connect(searchBox.FocusLost, function(enterPressed)
        tw(sStroke, TI_HOVER, { Color = COLORS.SearchBorder })
        tw(searchIcon, TI_HOVER, { ImageColor3 = COLORS.Icon })
        if enterPressed and data.expanded and searchBox.Text ~= "" then
            for _, row in ipairs(optRows) do
                if row.frame.Visible then
                    selectValue(row.value)
                    break
                end
            end
        end
    end)

    connect(clearBtn.Activated, function()
        searchBox.Text = ""
        if not MOBILE then
            searchBox:CaptureFocus()
        end
    end)

    connect(clearBtn.MouseEnter, function()
        tw(clearBtn, TI_HOVER, { ImageColor3 = COLORS.IconActive })
    end)

    connect(clearBtn.MouseLeave, function()
        tw(clearBtn, TI_HOVER, { ImageColor3 = COLORS.Icon })
    end)

    connect(userInputService.InputBegan, function(input)
        if destroyed or not data.expanded then return end
        if os.clock() - openedAt < 0.15 then return end
        if not isPointerInput(input) then return end
        local pos = Vector2.new(input.Position.X, input.Position.Y)
        if not isInside(field, pos) and not isInside(overlay, pos) then
            closeOverlay(false)
        end
    end)

    buildOptions()
    updateField(false)

    if hasSelection() then
        fireCallback()
    end

    local function sameSelection(a, b)
        if multi then
            for k in pairs(a) do
                if not b[k] then return false end
            end
            for k in pairs(b) do
                if not a[k] then return false end
            end
            return true
        end
        return a == b
    end

    function data:Set(value)
        if destroyed then return end
        local new
        if multi then
            new = {}
            if type(value) == "table" then
                for _, v in ipairs(value) do
                    if hasValue(v) then new[v] = true end
                end
            end
        else
            if value ~= nil and not hasValue(value) then
                warnf("value '" .. tostring(value) .. "' does not exist.")
                return
            end
            new = value
        end
        if sameSelection(data.value, new) then return end
        data.value = new
        for _, row in ipairs(optRows) do updateRow(row, true) end
        updateField(true)
        fireCallback()
    end

    function data:Get()
        return getOutput()
    end

    function data:SetValues(newValues)
        if destroyed then return end
        values = type(newValues) == "table" and newValues or {}

        local changed = false
        if multi then
            local f = {}
            for v in pairs(data.value) do
                if hasValue(v) then
                    f[v] = true
                else
                    changed = true
                end
            end
            data.value = f
        elseif data.value ~= nil and not hasValue(data.value) then
            data.value = nil
            changed = true
        end

        buildOptions()
        updateField(false)

        if #values == 0 and data.expanded then
            closeOverlay(true)
        elseif data.expanded then
            task.defer(reposition)
        end

        if changed then
            fireCallback()
        end
    end

    function data:SetDisabled(value)
        if destroyed then return end
        data.disabled = value == true
        field.Active = not data.disabled
        if data.disabled then closeOverlay(true) end
        for _, row in ipairs(optRows) do updateRow(row, false) end
        updateField(true)
        updateFieldBorder()
    end

    function data:SetTitle(newTitle)
        if destroyed then return end
        title = tostring(newTitle or "")
        titleLabel.Text = title
        container.Name = title .. "_Dropdown"
        overlay.Name = title .. "_Overlay"
    end

    function data:SetDescription(newDesc)
        if destroyed then return end
        newDesc = tostring(newDesc or "")
        if newDesc == "" then
            if descLabel then
                descLabel:Destroy()
                descLabel = nil
            end
            layoutText()
            return
        end
        if not descLabel then
            createDescription(newDesc)
        else
            descLabel.Text = breakWords(newDesc, WORD_BREAK)
        end
        layoutText()
    end

    function data:Open()
        openOverlay()
    end

    function data:Close()
        closeOverlay(false)
    end

    function data:Destroy()
        if destroyed then return end
        destroyed = true
        stopFollow()
        cancelTweens()
        clearRowConnections()
        for _, conn in ipairs(connections) do
            conn:Disconnect()
        end
        table.clear(connections)
        overlay:Destroy()
        container:Destroy()
    end

    return data
end)
