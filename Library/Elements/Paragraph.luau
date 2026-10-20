-- // Paragraph
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
        ArrowBg = Color3.fromRGB(24, 24, 24),
        ArrowStroke = Color3.fromRGB(50, 50, 56),
        ArrowStrokeHover = Color3.fromRGB(110, 110, 120),
        Icon = Color3.fromRGB(190, 190, 200),
        CornerText = Color3.fromRGB(200, 200, 208),
        BarTrack = Color3.fromRGB(34, 34, 38),
        BarFill = Color3.fromRGB(255, 255, 255),
        DotActive = Color3.fromRGB(255, 255, 255),
        DotInactive = Color3.fromRGB(70, 70, 78),
        ScrollBar = Color3.fromRGB(80, 80, 90),
    }

    local players = Players or game:GetService("Players")
    local userInputService = UserInputService or game:GetService("UserInputService")
    local tweenService = TweenService or game:GetService("TweenService")
    local runService = game:GetService("RunService")
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
    local ARROW_SIZE = MOBILE and 30 or 26
    local ARROW_PAD = 8
    local EDGE_PAD = 10
    local STATUS_LEFT = ARROW_SIZE + ARROW_PAD + 10
    local STATUS_RIGHT = 14
    local STAT_H = 18
    local STAT_BAR_H = 28
    local PADDING_X = 0
    local PADDING_Y = 10
    local THUMB_GAP = 10
    local MIN_HEIGHT = 40
    local UPDATE_INTERVAL = MOBILE and 5 or 3
    local WORD_MAX = 30
    local CAMERA_FOV = 40
    local DEFAULT_SPEED = 40

    local TI_PAGE = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local TI_FAST = TweenInfo.new(0.12)
    local TI_BAR = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local TI_SCAN = TweenInfo.new(2.6, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1)

    local connections = {}
    local destroyed = false
    local liveToken = 0
    local holoToken = 0
    local holoLiveToken = 0
    local thumbWarned = false
    local currentPage = "hologram"
    local holoModel
    local holoAngle = 0
    local holoSignature
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

    local function tw(obj, info, props)
        if destroyed or not obj or not obj.Parent then return end
        pcall(function()
            tweenService:Create(obj, info, props):Play()
        end)
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
        if number % 1 == 0 then return tostring(number) end
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
    viewport.BackgroundTransparency = 1
    viewport.ImageTransparency = 0.05
    viewport.Ambient = Color3.fromRGB(150, 150, 160)
    viewport.LightColor = Color3.fromRGB(255, 255, 255)
    viewport.LightDirection = Vector3.new(0.3, -0.5, 1)
    viewport.ZIndex = 3
    viewport.Parent = holoPage

    local holoCamera = Instance.new("Camera")
    holoCamera.FieldOfView = CAMERA_FOV
    holoCamera.Parent = viewport
    viewport.CurrentCamera = holoCamera

    local fallbackImage = Instance.new("ImageLabel")
    fallbackImage.Name = "Fallback"
    fallbackImage.Size = UDim2.fromOffset(CARD_H - 44, CARD_H - 44)
    fallbackImage.Position = UDim2.new(0.5, 0, 0.5, 0)
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
    statusHeader.Size = UDim2.new(1, -(STATUS_LEFT + STATUS_RIGHT), 0, 16)
    statusHeader.Position = UDim2.new(0, STATUS_LEFT, 0, 10)
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
    statusLine.Size = UDim2.new(1, -(STATUS_LEFT + STATUS_RIGHT), 0, 1)
    statusLine.Position = UDim2.new(0, STATUS_LEFT, 0, 30)
    statusLine.BackgroundColor3 = COLORS.Line
    statusLine.BorderSizePixel = 0
    statusLine.Parent = statusPage

    local statusScroll = Instance.new("ScrollingFrame")
    statusScroll.Name = "List"
    statusScroll.Size = UDim2.new(1, -(STATUS_LEFT + STATUS_RIGHT), 1, -46)
    statusScroll.Position = UDim2.new(0, STATUS_LEFT, 0, 38)
    statusScroll.BackgroundTransparency = 1
    statusScroll.BorderSizePixel = 0
    statusScroll.ScrollBarThickness = MOBILE and 3 or 2
    statusScroll.ScrollBarImageColor3 = COLORS.ScrollBar
    statusScroll.ScrollingDirection = Enum.ScrollingDirection.Y
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

    local function createArrow(name, image, anchor, position)
        local button = Instance.new("ImageButton")
        button.Name = name
        button.Size = UDim2.fromOffset(ARROW_SIZE, ARROW_SIZE)
        button.AnchorPoint = anchor
        button.Position = position
        button.BackgroundColor3 = COLORS.ArrowBg
        button.BackgroundTransparency = 0.1
        button.AutoButtonColor = false
        button.Selectable = false
        button.Image = ""
        button.Visible = false
        button.ZIndex = 8
        button.Parent = card
        addCorner(button, 99)
        local stroke = addStroke(button, COLORS.ArrowStroke, 1)

        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.fromOffset(14, 14)
        icon.Position = UDim2.new(0.5, 0, 0.5, 0)
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.BackgroundTransparency = 1
        icon.Image = image
        icon.ImageColor3 = COLORS.Icon
        icon.ZIndex = 9
        icon.Parent = button

        connect(button.MouseEnter, function()
            if userInputService:GetLastInputType() == Enum.UserInputType.Touch then return end
            tw(stroke, TI_FAST, { Color = COLORS.ArrowStrokeHover })
            tw(icon, TI_FAST, { ImageColor3 = COLORS.TextActive })
        end)
        connect(button.MouseLeave, function()
            tw(stroke, TI_FAST, { Color = COLORS.ArrowStroke })
            tw(icon, TI_FAST, { ImageColor3 = COLORS.Icon })
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

    -- // Thumbnail
    local function layoutThumbnail(hasThumb)
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
        local ok, result = pcall(function()
            return players:GetUserThumbnailAsync(
                userId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size100x100
            )
        end)
        if ok and result then
            thumbWarned = false
            return result
        end
        if not thumbWarned then
            thumbWarned = true
            warnf("Failed to fetch thumbnail for userId " .. tostring(userId))
        end
        return nil
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
                if thumbImage.Image == "" or isShown() then
                    local img = fetchUserThumb(userId)
                    if destroyed or liveToken ~= myToken then return end
                    if img and thumbImage.Image ~= img then
                        thumbImage.Image = img
                    end
                end
                task.wait(UPDATE_INTERVAL)
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

    -- // Pages
    local function hasHologram()
        return data.hologram ~= nil
    end

    local function hasStatus()
        return #statusList > 0
    end

    local function applyPage(animate)
        local onHolo = currentPage == "hologram"
        local holoPosition = onHolo and UDim2.new(0, 0, 0, 0) or UDim2.new(-1, 0, 0, 0)
        local statusPosition = onHolo and UDim2.new(1, 0, 0, 0) or UDim2.new(0, 0, 0, 0)

        if animate then
            tw(holoPage, TI_PAGE, { Position = holoPosition })
            tw(statusPage, TI_PAGE, { Position = statusPosition })
        else
            holoPage.Position = holoPosition
            statusPage.Position = statusPosition
        end

        local both = hasHologram() and hasStatus()
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
    end

    local function syncPage()
        if currentPage == "status" and not hasStatus() then
            currentPage = "hologram"
        end
        if currentPage == "hologram" and not hasHologram() and hasStatus() then
            currentPage = "status"
        end
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

    -- // Status
    local function statHasBar(stat)
        return stat.max ~= nil and stat.max > 0 and tonumber(stat.value) ~= nil
    end

    local function formatStat(stat)
        if stat.max ~= nil and tonumber(stat.value) ~= nil then
            return formatNumber(stat.value) .. "/" .. formatNumber(stat.max)
        end
        return tostring(stat.value)
    end

    local function createStatRow(stat, index)
        local hasBar = statHasBar(stat)

        local row = Instance.new("Frame")
        row.Name = "Stat_" .. index
        row.Size = UDim2.new(1, 0, 0, hasBar and STAT_BAR_H or STAT_H)
        row.BackgroundTransparency = 1
        row.LayoutOrder = index
        row.Parent = statusScroll

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "Name"
        nameLabel.Size = UDim2.new(0.6, 0, 0, 16)
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
        valueLabel.Size = UDim2.new(0.4, 0, 0, 16)
        valueLabel.Position = UDim2.new(0.6, 0, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = formatStat(stat)
        valueLabel.TextColor3 = COLORS.TextActive
        valueLabel.TextSize = DESC_SIZE + 1
        valueLabel.Font = fontBold
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
        valueLabel.RichText = richText
        valueLabel.Parent = row

        local fill
        if hasBar then
            local track = Instance.new("Frame")
            track.Name = "Track"
            track.Size = UDim2.new(1, 0, 0, 3)
            track.Position = UDim2.new(0, 0, 0, 21)
            track.BackgroundColor3 = COLORS.BarTrack
            track.BorderSizePixel = 0
            track.Parent = row
            addCorner(track, 99)

            local ratio = math.clamp(tonumber(stat.value) / stat.max, 0, 1)
            fill = Instance.new("Frame")
            fill.Name = "Fill"
            fill.Size = UDim2.new(ratio, 0, 1, 0)
            fill.BackgroundColor3 = COLORS.BarFill
            fill.BorderSizePixel = 0
            fill.Parent = track
            addCorner(fill, 99)
        end

        return { frame = row, nameLabel = nameLabel, valueLabel = valueLabel, fill = fill }
    end

    local function rebuildStatus()
        for _, row in ipairs(statusRows) do
            row.frame:Destroy()
        end
        statusRows = {}
        for index, stat in ipairs(statusList) do
            table.insert(statusRows, createStatRow(stat, index))
        end
        syncPage()
    end

    local function refreshStat(index)
        local stat = statusList[index]
        local row = statusRows[index]
        if not stat or not row then return end
        if (row.fill ~= nil) ~= statHasBar(stat) then
            rebuildStatus()
            return
        end
        row.nameLabel.Text = stat.name
        row.valueLabel.Text = formatStat(stat)
        if row.fill then
            local ratio = math.clamp(tonumber(stat.value) / stat.max, 0, 1)
            tw(row.fill, TI_BAR, { Size = UDim2.new(ratio, 0, 1, 0) })
        end
    end

    -- // Hologram
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
            label.Text = text
            label.Visible = text ~= ""
        end
    end

    local function clearHologram()
        if holoModel then
            holoModel:Destroy()
            holoModel = nil
        end
        holoSignature = nil
        fallbackImage.Image = ""
        fallbackImage.Visible = false
    end

    local function cleanModel(model, tint)
        for _, descendant in ipairs(model:GetDescendants()) do
            if descendant:IsA("BaseScript") or descendant:IsA("Sound") then
                descendant:Destroy()
            elseif descendant:IsA("BasePart") then
                descendant.Anchored = true
                descendant.CanCollide = false
                descendant.Transparency = descendant.Transparency + (1 - descendant.Transparency) * 0.25
                if tint then
                    descendant.Color = descendant.Color:Lerp(tint, 0.4)
                end
            end
        end
    end

    local function buildHolder(source, tint)
        local previous = source.Archivable
        pcall(function()
            source.Archivable = true
        end)
        local cloned, clone = pcall(function()
            return source:Clone()
        end)
        pcall(function()
            source.Archivable = previous
        end)
        if not cloned or not clone then return nil end

        local holder = clone
        if not clone:IsA("Model") then
            holder = Instance.new("Model")
            clone.Parent = holder
        end

        cleanModel(holder, tint)

        local measured, boxCFrame, boxSize = pcall(function()
            return holder:GetBoundingBox()
        end)
        if not measured or boxSize.Magnitude <= 0 then
            holder:Destroy()
            return nil
        end

        holder.PrimaryPart = nil
        holder.WorldPivot = boxCFrame
        holder:PivotTo(CFrame.new())
        return holder, boxSize
    end

    local function mountHolder(holder, size)
        local radius = math.max(size.Magnitude * 0.5, 0.5)
        local distance = radius / math.sin(math.rad(holoCamera.FieldOfView * 0.5)) * 0.95
        holoCamera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -distance), Vector3.zero)
        holder:PivotTo(CFrame.Angles(0, math.rad(holoAngle), 0))
        holder.Parent = viewport
        holoModel = holder
        fallbackImage.Visible = false
    end

    local function getUserId(target, kind)
        if kind == "item" then return nil end
        if type(target) == "number" then return target end
        if kind == "character" then return tonumber(target) end
        return nil
    end

    local function resolveSource(target, kind)
        if typeof(target) == "Instance" then
            return target, nil, false
        end

        local userId = getUserId(target, kind)
        if userId then
            local player = players:GetPlayerByUserId(userId)
            if player and player.Character then
                return player.Character, nil, false
            end
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

        local assetId = tostring(target):match("%d+")
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
        return nil, "rbxassetid://" .. assetId, false
    end

    local function getSignature(source)
        local parts = { tostring(#source:GetDescendants()) }
        for _, child in ipairs(source:GetChildren()) do
            local extra = ""
            if child:IsA("Shirt") then
                extra = child.ShirtTemplate
            elseif child:IsA("Pants") then
                extra = child.PantsTemplate
            elseif child:IsA("ShirtGraphic") then
                extra = child.Graphic
            end
            table.insert(parts, child.Name .. extra)
        end
        return table.concat(parts, "|")
    end

    local function getLiveSource(config)
        local target = config.target
        if typeof(target) == "Instance" then
            return target.Parent and target or nil
        end
        local userId = getUserId(target, config.type)
        if userId then
            local player = players:GetPlayerByUserId(userId)
            return player and player.Character or nil
        end
        return nil
    end

    local function loadHologram()
        holoToken = holoToken + 1
        local token = holoToken
        local config = data.hologram

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
                local signature = not temporary and getSignature(source) or nil
                local holder, size = buildHolder(source, config.tint)
                if temporary then
                    source:Destroy()
                end
                if holder then
                    clearHologram()
                    holoSignature = signature
                    mountHolder(holder, size)
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

    local function pollHologram()
        local config = data.hologram
        if not config then return end
        local source = getLiveSource(config)
        if not source then return end
        local signature = getSignature(source)
        if signature == holoSignature then return end
        local holder, size = buildHolder(source, config.tint)
        if not holder then return end
        clearHologram()
        holoSignature = signature
        mountHolder(holder, size)
    end

    local function startHologramLive()
        holoLiveToken = holoLiveToken + 1
        local myToken = holoLiveToken

        task.spawn(function()
            while not destroyed and holoLiveToken == myToken do
                task.wait(UPDATE_INTERVAL)
                if destroyed or holoLiveToken ~= myToken then return end
                if currentPage == "hologram" and data.hologram and isShown() then
                    pollHologram()
                end
            end
        end)
    end

    connect(runService.RenderStepped, function(delta)
        if destroyed or not holoModel or currentPage ~= "hologram" then return end
        local config = data.hologram
        if not config or not config.rotate then return end
        shownClock = shownClock + delta
        if shownClock >= 0.5 then
            shownClock = 0
            shownCache = isShown()
        end
        if not shownCache then return end
        holoAngle = (holoAngle + delta * config.speed) % 360
        holoModel:PivotTo(CFrame.Angles(0, math.rad(holoAngle), 0))
    end)

    connect(nextButton.Activated, function()
        setPage("status", true)
    end)

    connect(backButton.Activated, function()
        setPage("hologram", true)
    end)

    scanTween = tweenService:Create(scan, TI_SCAN, { Position = UDim2.new(0, 0, 1, 0) })
    scanTween:Play()

    setThumbnailInternal(thumbnail)
    applyBackground()
    applyCorners()
    rebuildStatus()
    loadHologram()
    startHologramLive()
    applyDisabled()
    updateRowVisibility()

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
        data.hologram = normalizeHologram(config)
        applyBackground()
        applyCorners()
        loadHologram()
        syncPage()
    end

    function data:SetTarget(target, kind)
        if destroyed then return end
        if not data.hologram then
            data.hologram = normalizeHologram({})
        end
        data.hologram.target = target
        if kind ~= nil then
            data.hologram.type = kind
        end
        loadHologram()
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
        statusList = normalizeStatus(list)
        rebuildStatus()
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
        for _, conn in ipairs(connections) do
            conn:Disconnect()
        end
        table.clear(connections)
        clearHologram()
        container:Destroy()
    end

    return data
end)