Elements.Register("Paragraph", function(section, options)
    options = type(options) == "table" and options or {}

    local COLORS = {
        TextActive = Color3.fromRGB(255, 255, 255),
        TextDisabled = Color3.fromRGB(70, 70, 78),
        DescText = Color3.fromRGB(105, 105, 115),
        DescDisabled = Color3.fromRGB(60, 60, 68),
        Line = Color3.fromRGB(32, 32, 32),
        ThumbBg = Color3.fromRGB(24, 24, 24),
        CardBg = Color3.fromRGB(16, 16, 16),
        CardStroke = Color3.fromRGB(38, 38, 38),
        StatusBg = Color3.fromRGB(18, 18, 18),
        Icon = Color3.fromRGB(190, 190, 200),
        CornerText = Color3.fromRGB(200, 200, 208),
        DotActive = Color3.fromRGB(255, 255, 255),
        DotInactive = Color3.fromRGB(70, 70, 78),
        ScrollBar = Color3.fromRGB(80, 80, 90),
    }

    local REMOVABLE = {
        Script = true,
        LocalScript = true,
        ModuleScript = true,
        Sound = true,
        ForceField = true,
        BillboardGui = true,
        SurfaceGui = true,
        ParticleEmitter = true,
        Trail = true,
        Beam = true,
        Highlight = true,
        SelectionBox = true,
        PointLight = true,
        SpotLight = true,
        SurfaceLight = true,
        Smoke = true,
        Fire = true,
        Sparkles = true,
    }

    local players = Players or game:GetService("Players")
    local userInputService = UserInputService or game:GetService("UserInputService")
    local tweenService = TweenService or game:GetService("TweenService")
    local runService = game:GetService("RunService")
    local contentProvider = game:GetService("ContentProvider")
    local insertService = game:GetService("InsertService")
    local fontBold = FONT_BOLD or Enum.Font.SourceSansBold
    local fontRegular = FONT or Enum.Font.SourceSans
    local chevronRight = (ICONS and ICONS.assets and ICONS.assets["lucide-chevron-right"]) or "rbxassetid://10709791437"
    local chevronLeft = (ICONS and ICONS.assets and ICONS.assets["lucide-chevron-left"]) or "rbxassetid://10709791281"

    local MOBILE = userInputService.TouchEnabled and not userInputService.KeyboardEnabled

    local TITLE_SIZE = MOBILE and 13 or 12
    local DESC_SIZE = MOBILE and 11 or 10
    local CORNER_SIZE = MOBILE and 11 or 10
    local THUMB_SIZE = MOBILE and 40 or 36
    local CARD_H = MOBILE and 156 or 140
    local ARROW_SIZE = MOBILE and 38 or 28
    local ICON_SIZE = MOBILE and 20 or 16
    local ARROW_PAD = 6
    local EDGE_PAD = 10
    local STATUS_LEFT_BACK = ARROW_SIZE + ARROW_PAD + 4
    local STATUS_LEFT_NORMAL = 14
    local STATUS_RIGHT = 14
    local STAT_H = MOBILE and 20 or 18
    local HOLO_LIFT = MOBILE and 12 or 10
    local HOLO_MARGIN = 1.08
    local HOLO_STEP = 1 / 30
    local HOLO_CULL_PARTS = 700
    local HOLO_CULL_RATIO = 0.004
    local HOLO_CHUNK = 250
    local HOLO_HIDDEN = 0.99
    local PRELOAD_TIMEOUT = 8
    local STABLE_TIMEOUT = 3
    local STREAM_TIMEOUT = 2
    local HOLO_PITCH_ITEM = 16
    local HOLO_PITCH_CHAR = 6
    local PADDING_X = 0
    local PADDING_Y = 10
    local THUMB_GAP = 10
    local MIN_HEIGHT = 40
    local UPDATE_INTERVAL = MOBILE and 5 or 3
    local THUMB_INTERVAL = 30
    local WORD_MAX = 30
    local CAMERA_FOV = 40
    local DEFAULT_SPEED = 40

    local TI_PAGE = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local TI_FAST = TweenInfo.new(0.12)
    local TI_SCAN = TweenInfo.new(2.6, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1)

    local connections = {}
    local holoWatch = {}
    local activeTweens = setmetatable({}, { __mode = "k" })
    local destroyed = false
    local liveToken = 0
    local holoToken = 0
    local holoLiveToken = 0
    local thumbWarned = false
    local currentPage = "hologram"
    local layoutKey
    local holoModel
    local holoSize
    local holoPitch = HOLO_PITCH_ITEM
    local holoAngle = 0
    local holoDistance = 0
    local holoBaseLight = Vector3.new(0.3, -0.5, 1)
    local holoSignature
    local rotateAcc = 0
    local reloadPending = false
    local building = false
    local shownCache = true
    local shownClock = 0
    local scanTween
    local statusList = {}
    local statusRows = {}

    local function connect(signal, fn)
        local conn = signal:Connect(fn)
        table.insert(connections, conn)
        return conn
    end

    local function warnf(msg)
        pcall(function()
            Notify({ Title = "Ecohub | Paragraph", Description = msg, Duration = 5 })
        end)
    end

    local function stopTween(obj)
        local running = activeTweens[obj]
        if running then
            activeTweens[obj] = nil
            running:Cancel()
        end
    end

    local function tw(obj, info, props)
        if destroyed or not obj or not obj.Parent then return end
        stopTween(obj)
        local ok, tween = pcall(function()
            return tweenService:Create(obj, info, props)
        end)
        if ok and tween then
            activeTweens[obj] = tween
            tween:Play()
        end
    end

    local function breakLongWords(text, maxLen)
        text = tostring(text or "")
        local lines = {}
        for line in (text .. "\n"):gmatch("(.-)\n") do
            local result = {}
            for word in line:gmatch("%S+") do
                while #word > maxLen do
                    table.insert(result, word:sub(1, maxLen))
                    word = word:sub(maxLen + 1)
                end
                table.insert(result, word)
            end
            table.insert(lines, table.concat(result, " "))
        end
        return table.concat(lines, "\n")
    end

    local function normalizeImage(value)
        if value == nil or value == "" then return "" end
        local text = tostring(value)
        if text:match("^%d+$") then
            return "rbxassetid://" .. text
        end
        return text
    end

    local function formatNumber(value)
        local number = tonumber(value)
        if not number then return tostring(value) end
        if number ~= number or math.abs(number) >= 1e15 then
            return tostring(number)
        end
        if number % 1 == 0 then
            return string.format("%d", number)
        end
        return string.format("%.1f", number)
    end

    local function copyTable(source)
        local result = {}
        if type(source) == "table" then
            for key, value in pairs(source) do
                result[key] = value
            end
        end
        return result
    end

    local function addCorner(instance, radius)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, radius)
        corner.Parent = instance
        return corner
    end

    local function addStroke(instance, color, thickness)
        local stroke = Instance.new("UIStroke")
        stroke.Color = color
        stroke.Thickness = thickness
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = instance
        return stroke
    end

    local title = tostring(options.title or options.Name or "")
    local description = tostring(options.description or options.Description or "")
    local thumbnail = options.thumbnail or options.Thumbnail
    local disabled = options.disabled == true
    local richText = options.richText ~= false
    local statusTitle = tostring(options.statusTitle or "Status")
    local callback = options.callback or options.Callback

    if type(callback) ~= "function" then
        callback = function() end
    end

    if thumbnail ~= nil and type(thumbnail) ~= "string" and type(thumbnail) ~= "number" then
        warnf("thumbnail must be a string or a number (userId)")
        thumbnail = nil
    end

    local function formatText(text)
        if richText then
            return text
        end
        return breakLongWords(text, WORD_MAX)
    end

    local function normalizeHologram(config)
        if config == nil then return nil end
        if type(config) ~= "table" then
            config = { target = config }
        end
        local background = config.background or config.Background or config.texture
        local transparency = tonumber(config.backgroundTransparency)
        local tint = config.tint
        return {
            target = config.target or config.Target,
            type = config.type or config.Type,
            background = background,
            backgroundTransparency = transparency or 0.5,
            backgroundTile = config.backgroundTile == true,
            corners = copyTable(config.corners or config.info),
            rotate = config.rotate ~= false,
            speed = tonumber(config.speed) or DEFAULT_SPEED,
            tint = typeof(tint) == "Color3" and tint or nil,
            live = config.live == true or config.Live == true,
            nonce = config.nonce,
        }
    end

    local function normalizeStat(entry)
        if type(entry) ~= "table" then return nil end
        local name = entry.name or entry.Name or entry[1]
        if name == nil then return nil end
        local value = entry.value
        if value == nil then value = entry.Value end
        if value == nil then value = entry[2] end
        if value == nil then value = "" end
        local max = entry.max or entry.Max or entry[3]
        return { name = tostring(name), value = value, max = tonumber(max) }
    end

    local function normalizeStatus(list)
        local result = {}
        if type(list) == "table" then
            for _, entry in ipairs(list) do
                local stat = normalizeStat(entry)
                if stat then
                    table.insert(result, stat)
                end
            end
        end
        return result
    end

    local data = {
        disabled = disabled,
        title = title,
        description = description,
        thumbnail = thumbnail,
        hologram = normalizeHologram(options.hologram or options.Hologram),
    }

    statusList = normalizeStatus(options.status or options.Status)

    local container = Instance.new("Frame")
    container.Name = (title ~= "" and title or "Paragraph") .. "_Paragraph"
    container.Size = UDim2.new(1, 0, 0, MIN_HEIGHT)
    container.BackgroundTransparency = 1
    container.ClipsDescendants = false
    container.AutomaticSize = Enum.AutomaticSize.Y
    container.Parent = section.frame

    local sizeConstraint = Instance.new("UISizeConstraint")
    sizeConstraint.MinSize = Vector2.new(0, MIN_HEIGHT)
    sizeConstraint.Parent = container

    local innerPad = Instance.new("UIPadding")
    innerPad.PaddingTop = UDim.new(0, PADDING_Y)
    innerPad.PaddingBottom = UDim.new(0, PADDING_Y)
    innerPad.PaddingLeft = UDim.new(0, PADDING_X)
    innerPad.PaddingRight = UDim.new(0, PADDING_X)
    innerPad.Parent = container

    local containerLayout = Instance.new("UIListLayout")
    containerLayout.SortOrder = Enum.SortOrder.LayoutOrder
    containerLayout.Padding = UDim.new(0, 10)
    containerLayout.Parent = container

    local rowFrame = Instance.new("Frame")
    rowFrame.Name = "Row"
    rowFrame.BackgroundTransparency = 1
    rowFrame.Size = UDim2.new(1, 0, 0, 0)
    rowFrame.AutomaticSize = Enum.AutomaticSize.Y
    rowFrame.LayoutOrder = 1
    rowFrame.Parent = container

    local rowConstraint = Instance.new("UISizeConstraint")
    rowConstraint.MinSize = Vector2.new(0, 0)
    rowConstraint.Parent = rowFrame

    local thumbFrame = Instance.new("Frame")
    thumbFrame.Name = "Thumbnail"
    thumbFrame.Size = UDim2.fromOffset(THUMB_SIZE, THUMB_SIZE)
    thumbFrame.Position = UDim2.new(0, 0, 0, 0)
    thumbFrame.BackgroundColor3 = COLORS.ThumbBg
    thumbFrame.BorderSizePixel = 0
    thumbFrame.Visible = thumbnail ~= nil
    thumbFrame.Parent = rowFrame
    addCorner(thumbFrame, 6)
    addStroke(thumbFrame, COLORS.Line, 1)

    local thumbImage = Instance.new("ImageLabel")
    thumbImage.Name = "Image"
    thumbImage.Size = UDim2.new(1, 0, 1, 0)
    thumbImage.BackgroundTransparency = 1
    thumbImage.Image = type(thumbnail) == "string" and thumbnail or ""
    thumbImage.ScaleType = Enum.ScaleType.Crop
    thumbImage.ZIndex = 2
    thumbImage.Parent = thumbFrame
    addCorner(thumbImage, 6)

    local textFrame = Instance.new("Frame")
    textFrame.Name = "TextBlock"
    textFrame.BackgroundTransparency = 1
    textFrame.Position = UDim2.new(0, 0, 0, 0)
    textFrame.Size = UDim2.new(1, 0, 0, 0)
    textFrame.AutomaticSize = Enum.AutomaticSize.Y
    textFrame.Parent = rowFrame

    local textLayout = Instance.new("UIListLayout")
    textLayout.SortOrder = Enum.SortOrder.LayoutOrder
    textLayout.Padding = UDim.new(0, 4)
    textLayout.Parent = textFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, 0, 0, 0)
    titleLabel.AutomaticSize = Enum.AutomaticSize.Y
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = formatText(title)
    titleLabel.TextColor3 = COLORS.TextActive
    titleLabel.TextSize = TITLE_SIZE
    titleLabel.Font = fontBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextYAlignment = Enum.TextYAlignment.Top
    titleLabel.TextWrapped = true
    titleLabel.RichText = richText
    titleLabel.LayoutOrder = 1
    titleLabel.Visible = title ~= ""
    titleLabel.Parent = textFrame

    local descLabel = Instance.new("TextLabel")
    descLabel.Name = "Description"
    descLabel.Size = UDim2.new(1, 0, 0, 0)
    descLabel.AutomaticSize = Enum.AutomaticSize.Y
    descLabel.BackgroundTransparency = 1
    descLabel.Text = formatText(description)
    descLabel.TextColor3 = COLORS.DescText
    descLabel.TextSize = DESC_SIZE
    descLabel.Font = fontRegular
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.TextWrapped = true
    descLabel.LineHeight = 1.2
    descLabel.RichText = richText
    descLabel.LayoutOrder = 2
    descLabel.Visible = description ~= ""
    descLabel.Parent = textFrame

    local card = Instance.new("Frame")
    card.Name = "Card"
    card.Size = UDim2.new(1, 0, 0, CARD_H)
    card.BackgroundColor3 = COLORS.CardBg
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.LayoutOrder = 2
    card.Visible = false
    card.Parent = container
    addCorner(card, 8)
    addStroke(card, COLORS.CardStroke, 1)

    local pages = Instance.new("Frame")
    pages.Name = "Pages"
    pages.Size = UDim2.new(1, 0, 1, 0)
    pages.BackgroundTransparency = 1
    pages.ClipsDescendants = true
    pages.ZIndex = 1
    pages.Parent = card

    local holoPage = Instance.new("Frame")
    holoPage.Name = "Hologram"
    holoPage.Size = UDim2.new(1, 0, 1, 0)
    holoPage.Position = UDim2.new(0, 0, 0, 0)
    holoPage.BackgroundColor3 = COLORS.CardBg
    holoPage.BorderSizePixel = 0
    holoPage.ClipsDescendants = true
    holoPage.Parent = pages
    addCorner(holoPage, 8)

    local backgroundImage = Instance.new("ImageLabel")
    backgroundImage.Name = "Background"
    backgroundImage.Size = UDim2.new(1, 0, 1, 0)
    backgroundImage.BackgroundTransparency = 1
    backgroundImage.Image = ""
    backgroundImage.ScaleType = Enum.ScaleType.Crop
    backgroundImage.Visible = false
    backgroundImage.ZIndex = 1
    backgroundImage.Parent = holoPage
    addCorner(backgroundImage, 8)

    local shade = Instance.new("Frame")
    shade.Name = "Shade"
    shade.Size = UDim2.new(1, 0, 1, 0)
    shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shade.BorderSizePixel = 0
    shade.ZIndex = 2
    shade.Parent = holoPage
    addCorner(shade, 8)

    local shadeGradient = Instance.new("UIGradient")
    shadeGradient.Rotation = 90
    shadeGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.35),
        NumberSequenceKeypoint.new(0.5, 0.85),
        NumberSequenceKeypoint.new(1, 0.35),
    })
    shadeGradient.Parent = shade

    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "Viewport"
    viewport.Size = UDim2.new(1, 0, 1, 0)
    viewport.Position = UDim2.new(0, 0, 0, -HOLO_LIFT)
    viewport.BackgroundTransparency = 1
    viewport.ImageTransparency = 0
    viewport.Ambient = Color3.fromRGB(190, 190, 200)
    viewport.LightColor = Color3.fromRGB(255, 255, 255)
    viewport.LightDirection = holoBaseLight
    viewport.ZIndex = 3
    viewport.Parent = holoPage

    local holoCamera = Instance.new("Camera")
    holoCamera.FieldOfView = CAMERA_FOV
    holoCamera.Parent = viewport
    viewport.CurrentCamera = holoCamera

    local fallbackImage = Instance.new("ImageLabel")
    fallbackImage.Name = "Fallback"
    fallbackImage.Size = UDim2.fromOffset(CARD_H - 44, CARD_H - 44)
    fallbackImage.Position = UDim2.new(0.5, 0, 0.5, -HOLO_LIFT)
    fallbackImage.AnchorPoint = Vector2.new(0.5, 0.5)
    fallbackImage.BackgroundTransparency = 1
    fallbackImage.Image = ""
    fallbackImage.ImageTransparency = 0.1
    fallbackImage.ScaleType = Enum.ScaleType.Fit
    fallbackImage.Visible = false
    fallbackImage.ZIndex = 3
    fallbackImage.Parent = holoPage

    local scan = Instance.new("Frame")
    scan.Name = "Scan"
    scan.Size = UDim2.new(1, 0, 0, 26)
    scan.Position = UDim2.new(0, 0, 0, -26)
    scan.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    scan.BorderSizePixel = 0
    scan.ZIndex = 4
    scan.Parent = holoPage

    local scanGradient = Instance.new("UIGradient")
    scanGradient.Rotation = 90
    scanGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.88),
        NumberSequenceKeypoint.new(1, 1),
    })
    scanGradient.Parent = scan

    local function createCorner(name, position, anchor, alignX, alignY, font, color)
        local label = Instance.new("TextLabel")
        label.Name = name
        label.Size = UDim2.new(0.5, -(EDGE_PAD + 14), 0, 16)
        label.AnchorPoint = anchor
        label.Position = position
        label.BackgroundTransparency = 1
        label.Text = ""
        label.TextColor3 = color
        label.TextSize = CORNER_SIZE
        label.Font = font
        label.TextXAlignment = alignX
        label.TextYAlignment = alignY
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.TextStrokeTransparency = 0.75
        label.RichText = richText
        label.Visible = false
        label.ZIndex = 5
        label.Parent = holoPage
        return label
    end

    local cornerLabels = {
        topLeft = createCorner("TopLeft", UDim2.new(0, EDGE_PAD, 0, EDGE_PAD), Vector2.new(0, 0), Enum.TextXAlignment.Left, Enum.TextYAlignment.Top, fontBold, COLORS.TextActive),
        topRight = createCorner("TopRight", UDim2.new(1, -EDGE_PAD, 0, EDGE_PAD), Vector2.new(1, 0), Enum.TextXAlignment.Right, Enum.TextYAlignment.Top, fontRegular, COLORS.DescText),
        bottomLeft = createCorner("BottomLeft", UDim2.new(0, EDGE_PAD, 1, -EDGE_PAD), Vector2.new(0, 1), Enum.TextXAlignment.Left, Enum.TextYAlignment.Bottom, fontRegular, COLORS.CornerText),
        bottomRight = createCorner("BottomRight", UDim2.new(1, -EDGE_PAD, 1, -EDGE_PAD), Vector2.new(1, 1), Enum.TextXAlignment.Right, Enum.TextYAlignment.Bottom, fontRegular, COLORS.DescText),
    }

    local statusPage = Instance.new("Frame")
    statusPage.Name = "Status"
    statusPage.Size = UDim2.new(1, 0, 1, 0)
    statusPage.Position = UDim2.new(1, 0, 0, 0)
    statusPage.BackgroundColor3 = COLORS.StatusBg
    statusPage.BorderSizePixel = 0
    statusPage.ClipsDescendants = true
    statusPage.Parent = pages
    addCorner(statusPage, 8)

    local statusHeader = Instance.new("TextLabel")
    statusHeader.Name = "Header"
    statusHeader.Size = UDim2.new(1, -(STATUS_LEFT_NORMAL + STATUS_RIGHT), 0, 16)
    statusHeader.Position = UDim2.new(0, STATUS_LEFT_NORMAL, 0, 10)
    statusHeader.BackgroundTransparency = 1
    statusHeader.Text = statusTitle
    statusHeader.TextColor3 = COLORS.TextActive
    statusHeader.TextSize = TITLE_SIZE
    statusHeader.Font = fontBold
    statusHeader.TextXAlignment = Enum.TextXAlignment.Left
    statusHeader.TextTruncate = Enum.TextTruncate.AtEnd
    statusHeader.Parent = statusPage

    local statusLine = Instance.new("Frame")
    statusLine.Name = "Line"
    statusLine.Size = UDim2.new(1, -(STATUS_LEFT_NORMAL + STATUS_RIGHT), 0, 1)
    statusLine.Position = UDim2.new(0, STATUS_LEFT_NORMAL, 0, 30)
    statusLine.BackgroundColor3 = COLORS.Line
    statusLine.BorderSizePixel = 0
    statusLine.Parent = statusPage

    local statusScroll = Instance.new("ScrollingFrame")
    statusScroll.Name = "List"
    statusScroll.Size = UDim2.new(1, -(STATUS_LEFT_NORMAL + STATUS_RIGHT), 1, -46)
    statusScroll.Position = UDim2.new(0, STATUS_LEFT_NORMAL, 0, 38)
    statusScroll.BackgroundTransparency = 1
    statusScroll.BorderSizePixel = 0
    statusScroll.ScrollBarThickness = 0
    statusScroll.ScrollBarImageColor3 = COLORS.ScrollBar
    statusScroll.ScrollingDirection = Enum.ScrollingDirection.Y
    statusScroll.ScrollingEnabled = false
    statusScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    statusScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    statusScroll.Parent = statusPage

    local statusLayout = Instance.new("UIListLayout")
    statusLayout.SortOrder = Enum.SortOrder.LayoutOrder
    statusLayout.Padding = UDim.new(0, 7)
    statusLayout.Parent = statusScroll

    local statusPad = Instance.new("UIPadding")
    statusPad.PaddingRight = UDim.new(0, 6)
    statusPad.Parent = statusScroll

    local function updateScrollState()
        local overflow = statusScroll.AbsoluteCanvasSize.Y > statusScroll.AbsoluteSize.Y + 1
        statusScroll.ScrollingEnabled = overflow
        statusScroll.ScrollBarThickness = overflow and (MOBILE and 3 or 2) or 0
    end

    connect(statusScroll:GetPropertyChangedSignal("AbsoluteCanvasSize"), updateScrollState)
    connect(statusScroll:GetPropertyChangedSignal("AbsoluteSize"), updateScrollState)

    local function layoutStatus(hasBack)
        local left = hasBack and STATUS_LEFT_BACK or STATUS_LEFT_NORMAL
        local width = -(left + STATUS_RIGHT)
        statusHeader.Position = UDim2.new(0, left, 0, 10)
        statusHeader.Size = UDim2.new(1, width, 0, 16)
        statusLine.Position = UDim2.new(0, left, 0, 30)
        statusLine.Size = UDim2.new(1, width, 0, 1)
        statusScroll.Position = UDim2.new(0, left, 0, 38)
        statusScroll.Size = UDim2.new(1, width, 1, -46)
    end

    local function createArrow(name, image, anchor, position)
        local button = Instance.new("ImageButton")
        button.Name = name
        button.Size = UDim2.fromOffset(ARROW_SIZE, ARROW_SIZE)
        button.AnchorPoint = anchor
        button.Position = position
        button.BackgroundTransparency = 1
        button.BorderSizePixel = 0
        button.AutoButtonColor = false
        button.Selectable = false
        button.Image = ""
        button.Visible = false
        button.ZIndex = 8
        button.Parent = card

        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
        icon.Position = UDim2.new(0.5, 0, 0.5, 0)
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.BackgroundTransparency = 1
        icon.Image = image
        icon.ImageColor3 = COLORS.Icon
        icon.ZIndex = 9
        icon.Parent = button

        connect(button.MouseEnter, function()
            if userInputService:GetLastInputType() == Enum.UserInputType.Touch then return end
            tw(icon, TI_FAST, { ImageColor3 = COLORS.TextActive })
        end)
        connect(button.MouseLeave, function()
            tw(icon, TI_FAST, { ImageColor3 = COLORS.Icon })
        end)
        connect(button.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                tw(icon, TI_FAST, { ImageColor3 = COLORS.TextActive })
            end
        end)
        connect(button.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                tw(icon, TI_FAST, { ImageColor3 = COLORS.Icon })
            end
        end)

        return button
    end

    local nextButton = createArrow("Next", chevronRight, Vector2.new(1, 0.5), UDim2.new(1, -ARROW_PAD, 0.5, 0))
    local backButton = createArrow("Back", chevronLeft, Vector2.new(0, 0.5), UDim2.new(0, ARROW_PAD, 0.5, 0))

    local dots = Instance.new("Frame")
    dots.Name = "Dots"
    dots.Size = UDim2.new(0, 40, 0, 6)
    dots.AnchorPoint = Vector2.new(0.5, 1)
    dots.Position = UDim2.new(0.5, 0, 1, -8)
    dots.BackgroundTransparency = 1
    dots.Visible = false
    dots.ZIndex = 8
    dots.Parent = card

    local dotsLayout = Instance.new("UIListLayout")
    dotsLayout.FillDirection = Enum.FillDirection.Horizontal
    dotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    dotsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    dotsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    dotsLayout.Padding = UDim.new(0, 6)
    dotsLayout.Parent = dots

    local function createDot(name, order, active)
        local dot = Instance.new("Frame")
        dot.Name = name
        dot.Size = UDim2.fromOffset(active and 14 or 6, 6)
        dot.BackgroundColor3 = active and COLORS.DotActive or COLORS.DotInactive
        dot.BorderSizePixel = 0
        dot.LayoutOrder = order
        dot.ZIndex = 8
        dot.Parent = dots
        addCorner(dot, 99)
        return dot
    end

    local dotHolo = createDot("DotHologram", 1, true)
    local dotStatus = createDot("DotStatus", 2, false)

    local veil = Instance.new("Frame")
    veil.Name = "Veil"
    veil.Size = UDim2.new(1, 0, 1, 0)
    veil.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    veil.BackgroundTransparency = 0.5
    veil.BorderSizePixel = 0
    veil.Active = true
    veil.Visible = false
    veil.ZIndex = 20
    veil.Parent = card
    addCorner(veil, 8)

    local function isShown()
        local node = container
        while node do
            if node:IsA("ScreenGui") then
                return node.Enabled
            end
            if node:IsA("GuiObject") and not node.Visible then
                return false
            end
            node = node.Parent
        end
        return false
    end

    local function syncScan()
        if not scanTween then return end
        if shownCache and currentPage == "hologram" then
            scanTween:Play()
        else
            scanTween:Pause()
        end
    end

    local function updateRowVisibility()
        rowFrame.Visible = data.title ~= "" or data.description ~= "" or (data.thumbnail ~= nil and data.thumbnail ~= "")
    end

    local function applyDisabled()
        titleLabel.TextColor3 = data.disabled and COLORS.TextDisabled or COLORS.TextActive
        descLabel.TextColor3 = data.disabled and COLORS.DescDisabled or COLORS.DescText
        thumbImage.ImageTransparency = data.disabled and 0.5 or 0
        veil.Visible = data.disabled
    end

    local function fireCallback(page)
        local ok, err = pcall(callback, page)
        if not ok then
            warnf("callback: " .. tostring(err))
        end
    end

    local function layoutThumbnail(hasThumb)
        rowConstraint.MinSize = Vector2.new(0, hasThumb and THUMB_SIZE or 0)
        if hasThumb then
            local offset = THUMB_SIZE + THUMB_GAP
            thumbFrame.Visible = true
            textFrame.Position = UDim2.new(0, offset, 0, 0)
            textFrame.Size = UDim2.new(1, -offset, 0, 0)
        else
            thumbFrame.Visible = false
            thumbImage.Image = ""
            textFrame.Position = UDim2.new(0, 0, 0, 0)
            textFrame.Size = UDim2.new(1, 0, 0, 0)
        end
    end

    local function fetchUserThumb(userId)
        local ok, result, ready = pcall(function()
            return players:GetUserThumbnailAsync(
                userId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size100x100
            )
        end)
        if ok and result then
            thumbWarned = false
            return result, ready ~= false
        end
        if not thumbWarned then
            thumbWarned = true
            warnf("Failed to fetch thumbnail for userId " .. tostring(userId))
        end
        return nil, false
    end

    local function stopThumbLive()
        liveToken = liveToken + 1
    end

    local function startThumbLive(userId)
        liveToken = liveToken + 1
        local myToken = liveToken
        thumbWarned = false

        task.spawn(function()
            while not destroyed and liveToken == myToken do
                local wait = THUMB_INTERVAL
                if thumbImage.Image == "" or isShown() then
                    local img, ready = fetchUserThumb(userId)
                    if destroyed or liveToken ~= myToken then return end
                    if img and thumbImage.Image ~= img then
                        thumbImage.Image = img
                    end
                    if not ready then
                        wait = UPDATE_INTERVAL
                    end
                end
                task.wait(wait)
            end
        end)
    end

    local function setThumbnailInternal(value)
        stopThumbLive()
        data.thumbnail = value

        if value == nil or value == "" then
            layoutThumbnail(false)
            updateRowVisibility()
            return
        end

        layoutThumbnail(true)

        if type(value) == "number" then
            thumbImage.Image = ""
            startThumbLive(value)
        elseif type(value) == "string" then
            thumbImage.Image = value
        else
            warnf("thumbnail must be a string or a number (userId)")
            layoutThumbnail(false)
        end

        updateRowVisibility()
    end

    local function hasHologram()
        return data.hologram ~= nil
    end

    local function hasStatus()
        return #statusList > 0
    end

    local function pageKey()
        return currentPage .. (hasHologram() and "1" or "0") .. (hasStatus() and "1" or "0")
    end

    local function applyPage(animate)
        layoutKey = pageKey()

        local onHolo = currentPage == "hologram"
        local holoPosition = onHolo and UDim2.new(0, 0, 0, 0) or UDim2.new(-1, 0, 0, 0)
        local statusPosition = onHolo and UDim2.new(1, 0, 0, 0) or UDim2.new(0, 0, 0, 0)

        if animate then
            tw(holoPage, TI_PAGE, { Position = holoPosition })
            tw(statusPage, TI_PAGE, { Position = statusPosition })
        else
            stopTween(holoPage)
            stopTween(statusPage)
            holoPage.Position = holoPosition
            statusPage.Position = statusPosition
        end

        local both = hasHologram() and hasStatus()
        layoutStatus(both)
        card.Visible = hasHologram() or hasStatus()
        nextButton.Visible = both and onHolo
        backButton.Visible = both and not onHolo
        dots.Visible = both

        tw(dotHolo, TI_FAST, {
            Size = UDim2.fromOffset(onHolo and 14 or 6, 6),
            BackgroundColor3 = onHolo and COLORS.DotActive or COLORS.DotInactive,
        })
        tw(dotStatus, TI_FAST, {
            Size = UDim2.fromOffset(onHolo and 6 or 14, 6),
            BackgroundColor3 = onHolo and COLORS.DotInactive or COLORS.DotActive,
        })

        syncScan()
    end

    local function syncPage()
        if currentPage == "status" and not hasStatus() then
            currentPage = "hologram"
        end
        if currentPage == "hologram" and not hasHologram() and hasStatus() then
            currentPage = "status"
        end
        if pageKey() == layoutKey then return end
        applyPage(false)
    end

    local function setPage(page, animate)
        if page ~= "hologram" and page ~= "status" then return end
        if page == "hologram" and not hasHologram() then return end
        if page == "status" and not hasStatus() then return end
        local changed = currentPage ~= page
        currentPage = page
        applyPage(animate)
        if changed then
            fireCallback(page)
        end
    end

    local function formatStat(stat)
        if stat.max ~= nil and tonumber(stat.value) ~= nil then
            return formatNumber(stat.value) .. "/" .. formatNumber(stat.max)
        end
        if type(stat.value) == "number" then
            return formatNumber(stat.value)
        end
        return tostring(stat.value)
    end

    local function createStatRow(stat, index)
        local row = Instance.new("Frame")
        row.Name = "Stat_" .. index
        row.Size = UDim2.new(1, 0, 0, STAT_H)
        row.BackgroundTransparency = 1
        row.LayoutOrder = index
        row.Parent = statusScroll

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "Name"
        nameLabel.Size = UDim2.new(0.5, 0, 1, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = stat.name
        nameLabel.TextColor3 = COLORS.DescText
        nameLabel.TextSize = DESC_SIZE + 1
        nameLabel.Font = fontRegular
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.RichText = richText
        nameLabel.Parent = row

        local valueLabel = Instance.new("TextLabel")
        valueLabel.Name = "Value"
        valueLabel.Size = UDim2.new(0.5, 0, 1, 0)
        valueLabel.Position = UDim2.new(0.5, 0, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = formatStat(stat)
        valueLabel.TextColor3 = COLORS.TextActive
        valueLabel.TextSize = DESC_SIZE + 1
        valueLabel.Font = fontBold
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
        valueLabel.RichText = richText
        valueLabel.Parent = row

        return { frame = row, nameLabel = nameLabel, valueLabel = valueLabel }
    end

    local function rebuildStatus()
        local savedPosition = statusScroll.CanvasPosition
        for _, row in ipairs(statusRows) do
            row.frame:Destroy()
        end
        statusRows = {}
        for index, stat in ipairs(statusList) do
            table.insert(statusRows, createStatRow(stat, index))
        end
        syncPage()
        task.defer(function()
            if not destroyed then
                statusScroll.CanvasPosition = savedPosition
            end
        end)
    end

    local function refreshStat(index)
        local stat = statusList[index]
        local row = statusRows[index]
        if not stat or not row then return end
        local text = formatStat(stat)
        if row.nameLabel.Text ~= stat.name then
            row.nameLabel.Text = stat.name
        end
        if row.valueLabel.Text ~= text then
            row.valueLabel.Text = text
        end
    end

    local function applyBackground()
        local config = data.hologram
        local image = config and normalizeImage(config.background) or ""
        if image == "" then
            backgroundImage.Image = ""
            backgroundImage.Visible = false
            return
        end
        backgroundImage.Image = image
        backgroundImage.ImageTransparency = config.backgroundTransparency
        if config.backgroundTile then
            backgroundImage.ScaleType = Enum.ScaleType.Tile
            backgroundImage.TileSize = UDim2.fromOffset(64, 64)
        else
            backgroundImage.ScaleType = Enum.ScaleType.Crop
        end
        backgroundImage.Visible = true
    end

    local function applyCorners()
        local corners = data.hologram and data.hologram.corners or {}
        for name, label in pairs(cornerLabels) do
            local text = corners[name]
            text = text == nil and "" or tostring(text)
            if label.Text ~= text then
                label.Text = text
            end
            label.Visible = text ~= ""
        end
    end

    local function applyOrbit()
        local rotation = CFrame.Angles(0, -math.rad(holoAngle), 0)
        local pitch = math.rad(holoPitch)
        local offset = Vector3.new(0, math.sin(pitch) * holoDistance, -math.cos(pitch) * holoDistance)
        holoCamera.CFrame = CFrame.lookAt(rotation * offset, Vector3.zero)
        viewport.LightDirection = rotation * holoBaseLight
    end

    local function fitCamera()
        if not holoSize then return end
        local size = holoSize
        local pitch = math.rad(holoPitch)
        local tanHalf = math.tan(math.rad(holoCamera.FieldOfView * 0.5))
        local viewSize = viewport.AbsoluteSize
        local aspect = viewSize.Y > 0 and viewSize.X / viewSize.Y or 2.5
        local radiusXZ = math.sqrt(size.X * size.X + size.Z * size.Z) * 0.5
        local extentY = size.Y * math.cos(pitch) + 2 * radiusXZ * math.sin(pitch)
        local fitY = extentY * 0.5 / tanHalf
        local fitX = radiusXZ / (tanHalf * aspect)
        holoDistance = math.max((math.max(fitY, fitX) + radiusXZ) * HOLO_MARGIN, 0.5)
        applyOrbit()
    end

    local function clearHologram()
        local old = holoModel
        holoModel = nil
        holoSize = nil
        if old then
            old.Parent = nil
            task.defer(old.Destroy, old)
        end
        holoSignature = nil
        fallbackImage.Image = ""
        fallbackImage.Visible = false
    end

    local function resetPose(model)
        local root = model:FindFirstChild("HumanoidRootPart")
        if not root or not root:IsA("BasePart") then return end

        local joints = {}
        for _, descendant in ipairs(model:GetDescendants()) do
            if descendant:IsA("JointInstance") and descendant.Part0 and descendant.Part1 then
                table.insert(joints, descendant)
            end
        end

        local targets = { [root] = root.CFrame }
        local progress = true
        local guard = 0
        while progress and guard < 64 do
            progress = false
            guard = guard + 1
            for _, joint in ipairs(joints) do
                local part0 = joint.Part0
                local part1 = joint.Part1
                if targets[part0] and not targets[part1] then
                    targets[part1] = targets[part0] * joint.C0 * joint.C1:Inverse()
                    progress = true
                elseif targets[part1] and not targets[part0] then
                    targets[part0] = targets[part1] * joint.C1 * joint.C0:Inverse()
                    progress = true
                end
            end
        end

        for _, joint in ipairs(joints) do
            joint:Destroy()
        end
        for part, cframe in pairs(targets) do
            part.CFrame = cframe
        end
    end

    local function cleanModel(model, tint, token)
        local isCharacter = model:FindFirstChildOfClass("Humanoid") ~= nil

        if isCharacter then
            for _, child in ipairs(model:GetChildren()) do
                if child:IsA("Tool") then
                    child:Destroy()
                end
            end
        end

        pcall(function()
            model.LevelOfDetail = Enum.ModelLevelOfDetail.Disabled
        end)

        local partList = {}
        local descendants = model:GetDescendants()

        for index, descendant in ipairs(descendants) do
            if descendant:IsA("BasePart") then
                descendant.Anchored = true
                descendant.CanCollide = false
                descendant.CanTouch = false
                descendant.CanQuery = false
                descendant.CastShadow = false
                if tint then
                    descendant.Color = descendant.Color:Lerp(tint, 0.4)
                end
                if descendant:IsA("MeshPart") then
                    pcall(function()
                        descendant.RenderFidelity = Enum.RenderFidelity.Precise
                    end)
                end
                partList[#partList + 1] = descendant
            elseif REMOVABLE[descendant.ClassName] then
                descendant:Destroy()
            end
            if index % HOLO_CHUNK == 0 then
                task.wait()
                if destroyed or holoToken ~= token then
                    return nil, isCharacter
                end
            end
        end

        if isCharacter then
            resetPose(model)
        end

        return partList, isCharacter
    end

    local function dropInvisible(partList)
        local kept = {}
        for index, part in ipairs(partList) do
            if part.Parent then
                if part.Transparency >= HOLO_HIDDEN then
                    part:Destroy()
                else
                    kept[#kept + 1] = part
                end
            end
            if index % HOLO_CHUNK == 0 then
                task.wait()
            end
        end
        return kept
    end

    local function cullParts(partList, limit)
        for index, part in ipairs(partList) do
            if part.Parent and part.Size.Magnitude < limit then
                part:Destroy()
            end
            if index % HOLO_CHUNK == 0 then
                task.wait()
            end
        end
    end

    local function measureHolder(holder)
        local root = holder:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then
            holder.PrimaryPart = root
        else
            holder.PrimaryPart = nil
            holder.WorldPivot = CFrame.new()
        end
        local measured, boxCFrame, boxSize = pcall(function()
            return holder:GetBoundingBox()
        end)
        holder.PrimaryPart = nil
        if not measured or boxSize.Magnitude <= 0 then
            return nil, nil
        end
        return boxCFrame, boxSize
    end

    local function waitStable(source, token)
        pcall(function()
            local localPlayer = players.LocalPlayer
            if localPlayer and workspace.StreamingEnabled and source:IsDescendantOf(workspace) then
                local position
                if source:IsA("Model") then
                    position = source:GetPivot().Position
                elseif source:IsA("BasePart") then
                    position = source.Position
                end
                if position then
                    localPlayer:RequestStreamAroundAsync(position, STREAM_TIMEOUT)
                end
            end
        end)

        local last = -1
        local stable = 0
        local started = os.clock()
        while os.clock() - started < STABLE_TIMEOUT do
            if destroyed or holoToken ~= token then return end
            local count = #source:GetDescendants()
            if count == last then
                stable = stable + 1
                if stable >= 2 then break end
            else
                stable = 0
                last = count
            end
            task.wait(0.2)
        end
    end

    local function cloneSource(source)
        local changed = {}
        local function force(instance)
            if not instance.Archivable then
                changed[#changed + 1] = instance
                pcall(function()
                    instance.Archivable = true
                end)
            end
        end
        force(source)
        for _, descendant in ipairs(source:GetDescendants()) do
            force(descendant)
        end
        local ok, clone = pcall(function()
            return source:Clone()
        end)
        for _, instance in ipairs(changed) do
            pcall(function()
                instance.Archivable = false
            end)
        end
        if ok then
            return clone
        end
        return nil
    end

    local function preloadHolder(holder, token)
        local finished = false
        task.spawn(function()
            pcall(function()
                contentProvider:PreloadAsync({ holder })
            end)
            finished = true
        end)
        local started = os.clock()
        while not finished and os.clock() - started < PRELOAD_TIMEOUT do
            if destroyed or holoToken ~= token then return end
            task.wait(0.05)
        end
    end

    local function buildHolder(source, tint, token)
        if not source:FindFirstChildOfClass("Humanoid") then
            waitStable(source, token)
        end
        if destroyed or holoToken ~= token then return nil end

        local clone = cloneSource(source)
        if not clone then return nil end

        local holder = clone
        if not clone:IsA("Model") then
            holder = Instance.new("Model")
            clone.Parent = holder
        end

        local partList, isCharacter = cleanModel(holder, tint, token)
        if not partList or destroyed or holoToken ~= token then
            holder:Destroy()
            return nil
        end

        if not isCharacter then
            partList = dropInvisible(partList)
            if #partList > HOLO_CULL_PARTS then
                local _, roughSize = measureHolder(holder)
                if roughSize then
                    cullParts(partList, roughSize.Magnitude * HOLO_CULL_RATIO)
                end
            end
            if destroyed or holoToken ~= token then
                holder:Destroy()
                return nil
            end
        end

        preloadHolder(holder, token)
        if destroyed or holoToken ~= token then
            holder:Destroy()
            return nil
        end

        local boxCFrame, boxSize = measureHolder(holder)
        if not boxCFrame then
            holder:Destroy()
            return nil
        end

        holder.WorldPivot = boxCFrame
        holder:PivotTo(CFrame.new())
        return holder, boxSize, isCharacter
    end

    local function mountHolder(holder, size, isCharacter)
        holoPitch = isCharacter and HOLO_PITCH_CHAR or HOLO_PITCH_ITEM
        holoSize = size
        holder.Parent = viewport
        holoModel = holder
        fitCamera()
        fallbackImage.Visible = false
    end

    local function isCharacterKind(kind)
        return kind == "character" or kind == "player"
    end

    local function resolveTarget(target, kind)
        if typeof(target) == "Instance" then
            if target:IsA("Player") then
                return target, target.UserId
            end
            if target:IsA("Model") then
                local owner = players:GetPlayerFromCharacter(target)
                if owner then
                    return owner, owner.UserId
                end
            end
            return nil, nil
        end

        if kind == "item" then return nil, nil end

        if type(target) == "number" then
            return players:GetPlayerByUserId(target), target
        end

        if type(target) == "string" then
            local lower = target:lower()
            if lower == "localplayer" and players.LocalPlayer then
                return players.LocalPlayer, players.LocalPlayer.UserId
            end
            local number = tonumber(target)
            if number then
                if isCharacterKind(kind) then
                    return players:GetPlayerByUserId(number), number
                end
                return nil, nil
            end
            for _, candidate in ipairs(players:GetPlayers()) do
                if candidate.Name:lower() == lower or candidate.DisplayName:lower() == lower then
                    return candidate, candidate.UserId
                end
            end
        end

        return nil, nil
    end

    local function extractAssetId(target)
        local text = tostring(target)
        return text:match("^%d+$") or text:match("^rbxassetid://(%d+)") or text:match("[?&]id=(%d+)")
    end

    local function findByPath(text)
        local lowered = text:lower()
        local node, rest
        if lowered:sub(1, 5) == "game." then
            node = game
            rest = text:sub(6)
        elseif lowered:sub(1, 10) == "workspace." then
            node = workspace
            rest = text:sub(11)
        else
            return nil
        end
        for name in rest:gmatch("[^%.]+") do
            node = node and node:FindFirstChild(name)
            if not node then return nil end
        end
        return node
    end

    local function resolveSource(target, kind)
        if type(target) == "string" then
            local found = findByPath(target)
            if found then
                target = found
            end
        end

        local player, userId = resolveTarget(target, kind)

        if typeof(target) == "Instance" and not player then
            if target:IsA("Decal") or target:IsA("Texture") then
                return nil, target.Texture, false
            end
            if target:IsA("ImageLabel") or target:IsA("ImageButton") then
                return nil, target.Image, false
            end
            return target, nil, false
        end

        if player and player.Character then
            return player.Character, nil, false
        end

        if userId then
            local modelOk, model = pcall(function()
                return players:CreateHumanoidModelFromUserId(userId)
            end)
            if modelOk and typeof(model) == "Instance" then
                return model, nil, true
            end
            local thumbOk, thumb = pcall(function()
                return players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
            end)
            if thumbOk and thumb then
                return nil, thumb, false
            end
            return nil, nil, false
        end

        local assetId = extractAssetId(target)
        if not assetId then
            return nil, nil, false
        end

        local objectsOk, objects = pcall(function()
            return game:GetObjects("rbxassetid://" .. assetId)
        end)
        local object = objectsOk and type(objects) == "table" and objects[1] or nil
        if object then
            if object:IsA("Model") or object:IsA("Tool") or object:IsA("Accessory") or object:IsA("BasePart") then
                return object, nil, true
            end
            local texture
            if object:IsA("Decal") or object:IsA("Texture") then
                texture = object.Texture
            end
            object:Destroy()
            if texture then
                return nil, texture, false
            end
        end

        local meshOk, meshPart = pcall(function()
            return insertService:CreateMeshPartAsync("rbxassetid://" .. assetId, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
        end)
        if meshOk and typeof(meshPart) == "Instance" then
            return meshPart, nil, true
        end

        return nil, "rbxassetid://" .. assetId, false
    end

    local function getSignature(source)
        local parts = {}
        if not source:FindFirstChildOfClass("Humanoid") then
            table.insert(parts, tostring(#source:GetDescendants()))
        end
        for _, child in ipairs(source:GetChildren()) do
            if child:IsA("Accessory") then
                table.insert(parts, "A" .. child.Name)
            elseif child:IsA("Shirt") then
                table.insert(parts, "S" .. child.ShirtTemplate)
            elseif child:IsA("Pants") then
                table.insert(parts, "P" .. child.PantsTemplate)
            elseif child:IsA("ShirtGraphic") then
                table.insert(parts, "G" .. child.Graphic)
            elseif child:IsA("BodyColors") then
                table.insert(parts, "C" .. tostring(child.HeadColor3) .. tostring(child.TorsoColor3) .. tostring(child.LeftArmColor3) .. tostring(child.RightArmColor3) .. tostring(child.LeftLegColor3) .. tostring(child.RightLegColor3))
            elseif child:IsA("BasePart") and child.Name == "Head" then
                local face = child:FindFirstChildOfClass("Decal")
                table.insert(parts, "H" .. (face and face.Texture or ""))
            end
        end
        table.sort(parts)
        return table.concat(parts, "|")
    end

    local function getLiveSource(config)
        local player = resolveTarget(config.target, config.type)
        if player then
            return player.Character
        end
        if config.live and typeof(config.target) == "Instance" then
            return config.target.Parent and config.target or nil
        end
        return nil
    end

    local function pollHologram()
        if building then return end
        local config = data.hologram
        if not config then return end
        local source = getLiveSource(config)
        if not source then return end
        local signature = getSignature(source)
        if signature == holoSignature then return end
        building = true
        local token = holoToken
        local ok, holder, size, isCharacter = pcall(buildHolder, source, config.tint, token)
        building = false
        if not ok or not holder then return end
        if destroyed or holoToken ~= token then
            holder:Destroy()
            return
        end
        clearHologram()
        holoSignature = signature
        mountHolder(holder, size, isCharacter)
    end

    local function clearWatch()
        for _, conn in ipairs(holoWatch) do
            conn:Disconnect()
        end
        table.clear(holoWatch)
    end

    local function scheduleReload()
        if reloadPending or destroyed then return end
        reloadPending = true
        task.delay(0.6, function()
            reloadPending = false
            if not destroyed then
                pollHologram()
            end
        end)
    end

    local function watchTarget(config)
        clearWatch()
        if not config or config.target == nil then return end
        local player = resolveTarget(config.target, config.type)
        if not player then return end
        table.insert(holoWatch, player.CharacterAdded:Connect(scheduleReload))
        table.insert(holoWatch, player.CharacterAppearanceLoaded:Connect(scheduleReload))
    end

    local function loadHologram()
        holoToken = holoToken + 1
        local token = holoToken
        local config = data.hologram

        watchTarget(config)

        if not config or config.target == nil then
            clearHologram()
            return
        end

        task.spawn(function()
            local source, image, temporary = resolveSource(config.target, config.type)
            if destroyed or holoToken ~= token then
                if temporary and source then
                    source:Destroy()
                end
                return
            end

            if source then
                local signature = nil
                if not temporary and getLiveSource(config) == source then
                    signature = getSignature(source)
                end
                local ok, holder, size, isCharacter = pcall(buildHolder, source, config.tint, token)
                if temporary then
                    source:Destroy()
                end
                if destroyed or holoToken ~= token then
                    if ok and holder then
                        holder:Destroy()
                    end
                    return
                end
                if ok and holder then
                    clearHologram()
                    holoSignature = signature
                    mountHolder(holder, size, isCharacter)
                    return
                end
            end

            clearHologram()
            if image then
                fallbackImage.Image = image
                fallbackImage.Visible = true
            end
        end)
    end

    local function startHologramLive()
        holoLiveToken = holoLiveToken + 1
        local myToken = holoLiveToken

        task.spawn(function()
            while not destroyed and holoLiveToken == myToken do
                task.wait(UPDATE_INTERVAL)
                if destroyed or holoLiveToken ~= myToken then return end
                if currentPage == "hologram" and data.hologram and shownCache then
                    pollHologram()
                end
            end
        end)
    end

    connect(viewport:GetPropertyChangedSignal("AbsoluteSize"), function()
        if holoModel then
            fitCamera()
        end
    end)

    connect(runService.RenderStepped, function(delta)
        if destroyed then return end
        shownClock = shownClock + delta
        if shownClock >= 0.5 then
            shownClock = 0
            local shown = isShown()
            if shown ~= shownCache then
                shownCache = shown
                syncScan()
            end
        end
        if not shownCache or not holoModel or currentPage ~= "hologram" then return end
        local config = data.hologram
        if not config or not config.rotate then return end
        rotateAcc = rotateAcc + delta
        if rotateAcc < HOLO_STEP then return end
        holoAngle = (holoAngle + rotateAcc * config.speed) % 360
        rotateAcc = 0
        applyOrbit()
    end)

    connect(nextButton.Activated, function()
        setPage("status", true)
    end)

    connect(backButton.Activated, function()
        setPage("hologram", true)
    end)

    scanTween = tweenService:Create(scan, TI_SCAN, { Position = UDim2.new(0, 0, 1, 0) })

    setThumbnailInternal(thumbnail)
    applyBackground()
    applyCorners()
    rebuildStatus()
    loadHologram()
    startHologramLive()
    applyDisabled()
    updateRowVisibility()
    updateScrollState()
    syncScan()

    function data:SetTitle(newTitle)
        if destroyed then return end
        newTitle = tostring(newTitle or "")
        data.title = newTitle
        titleLabel.Text = formatText(newTitle)
        titleLabel.Visible = newTitle ~= ""
        container.Name = (newTitle ~= "" and newTitle or "Paragraph") .. "_Paragraph"
        updateRowVisibility()
    end

    function data:SetDescription(newDesc)
        if destroyed then return end
        newDesc = tostring(newDesc or "")
        data.description = newDesc
        descLabel.Text = formatText(newDesc)
        descLabel.Visible = newDesc ~= ""
        updateRowVisibility()
    end

    function data:SetThumbnail(value)
        if destroyed then return end
        setThumbnailInternal(value)
    end

    function data:SetDisabled(value)
        if destroyed then return end
        data.disabled = value == true
        applyDisabled()
    end

    function data:GetTitle()
        return data.title
    end

    function data:GetDescription()
        return data.description
    end

    function data:SetHologram(config)
        if destroyed then return end
        local previous = data.hologram
        local updated = normalizeHologram(config)
        data.hologram = updated
        applyBackground()
        applyCorners()
        local unchanged = previous ~= nil
            and updated ~= nil
            and previous.target == updated.target
            and previous.type == updated.type
            and previous.tint == updated.tint
            and previous.live == updated.live
            and previous.nonce == updated.nonce
        if not unchanged then
            loadHologram()
        end
        syncPage()
    end

    function data:SetTarget(target, kind)
        if destroyed then return end
        if not data.hologram then
            data.hologram = normalizeHologram({})
        end
        local previousTarget = data.hologram.target
        local previousKind = data.hologram.type
        data.hologram.target = target
        if kind ~= nil then
            data.hologram.type = kind
        end
        if previousTarget ~= target or previousKind ~= data.hologram.type then
            loadHologram()
        end
        syncPage()
    end

    function data:SetBackground(id, transparency, tile)
        if destroyed then return end
        if not data.hologram then
            data.hologram = normalizeHologram({})
        end
        data.hologram.background = id
        if transparency ~= nil then
            data.hologram.backgroundTransparency = tonumber(transparency) or 0.5
        end
        if tile ~= nil then
            data.hologram.backgroundTile = tile == true
        end
        applyBackground()
        syncPage()
    end

    function data:SetCorners(corners)
        if destroyed then return end
        if not data.hologram then
            data.hologram = normalizeHologram({})
        end
        data.hologram.corners = copyTable(corners)
        applyCorners()
        syncPage()
    end

    function data:SetCorner(name, text)
        if destroyed then return end
        if not data.hologram then
            data.hologram = normalizeHologram({})
        end
        data.hologram.corners[name] = text
        applyCorners()
        syncPage()
    end

    function data:SetStatus(list)
        if destroyed then return end
        local newList = normalizeStatus(list)
        local same = #newList == #statusList
        if same then
            for index, stat in ipairs(newList) do
                if stat.name ~= statusList[index].name then
                    same = false
                    break
                end
            end
        end
        statusList = newList
        if same then
            for index = 1, #statusList do
                refreshStat(index)
            end
        else
            rebuildStatus()
        end
    end

    function data:SetStatusTitle(newTitle)
        if destroyed then return end
        statusTitle = tostring(newTitle or "")
        statusHeader.Text = statusTitle
    end

    function data:SetStat(name, value, max)
        if destroyed then return end
        name = tostring(name)
        for index, stat in ipairs(statusList) do
            if stat.name == name then
                stat.value = value
                if max ~= nil then
                    stat.max = tonumber(max)
                end
                refreshStat(index)
                return
            end
        end
        table.insert(statusList, { name = name, value = value, max = tonumber(max) })
        rebuildStatus()
    end

    function data:GetStat(name)
        name = tostring(name)
        for _, stat in ipairs(statusList) do
            if stat.name == name then
                return stat.value
            end
        end
        return nil
    end

    function data:RemoveStat(name)
        if destroyed then return end
        name = tostring(name)
        for index, stat in ipairs(statusList) do
            if stat.name == name then
                table.remove(statusList, index)
                rebuildStatus()
                return
            end
        end
    end

    function data:SetPage(page)
        if destroyed then return end
        setPage(page, true)
    end

    function data:GetPage()
        return currentPage
    end

    function data:Destroy()
        if destroyed then return end
        destroyed = true
        stopThumbLive()
        holoLiveToken = holoLiveToken + 1
        holoToken = holoToken + 1
        if scanTween then
            scanTween:Cancel()
            scanTween = nil
        end
        clearWatch()
        for _, conn in ipairs(connections) do
            conn:Disconnect()
        end
        table.clear(connections)
        clearHologram()
        container:Destroy()
    end

    table.insert(connections, container.Destroying:Connect(function()
        if not destroyed then
            data:Destroy()
        end
    end))

    return data
end)