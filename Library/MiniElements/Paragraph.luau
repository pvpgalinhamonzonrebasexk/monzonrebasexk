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
local DefaultDuration = 0.15
local BaseZIndex = 50

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
        return { Row = 46, Thumb = 64, Text = 13, Small = 11, Top = 44, Banner = 150 }
    end
    return { Row = 40, Thumb = 56, Text = 12, Small = 10, Top = 36, Banner = 130 }
end

local readDuration = function()
    local info = Tweens.Hover
    if typeof(info) == "TweenInfo" then
        return info.Time
    end
    return DefaultDuration
end

local resolveImage = function(value)
    if value == nil then
        return nil
    end
    if type(value) == "number" then
        return "rbxassetid://" .. tostring(math.floor(value))
    end
    local text = tostring(value)
    if text == "" then
        return nil
    end
    if text:match("^%d+$") then
        return "rbxassetid://" .. text
    end
    return text
end

local resolveStyle = function(value, hasImage)
    local text = string.lower(tostring(value or ""))
    if text == "thumbnail" or text == "hologram" or text == "holograma" or text == "image" then
        return "Thumbnail"
    end
    if text == "name" then
        return "Name"
    end
    return hasImage and "Thumbnail" or "Name"
end

local normalizeBlock = function(raw)
    if type(raw) == "string" then
        return { Text = raw }
    end
    if type(raw) == "table" then
        return {
            Header = raw.Header ~= nil and tostring(raw.Header) or nil,
            Text = raw.Text ~= nil and tostring(raw.Text) or nil,
            Image = resolveImage(raw.Image),
            Height = tonumber(raw.Height)
        }
    end
    return nil
end

local normalizeContent = function(raw)
    local blocks = {}
    if raw == nil then
        return blocks
    end
    if type(raw) == "string" then
        blocks[1] = { Text = raw }
        return blocks
    end
    if type(raw) ~= "table" then
        return blocks
    end
    if raw[1] == nil and (raw.Text ~= nil or raw.Header ~= nil or raw.Image ~= nil) then
        local single = normalizeBlock(raw)
        if single then
            blocks[1] = single
        end
        return blocks
    end
    for _, item in ipairs(raw) do
        local block = normalizeBlock(item)
        if block then
            blocks[#blocks + 1] = block
        end
    end
    return blocks
end

local findHost = function(start)
    local node = start.Parent
    while node do
        if node:IsA("GuiObject") or node:IsA("LayerCollector") then
            local free = true
            for _, child in ipairs(node:GetChildren()) do
                if child:IsA("UIGridStyleLayout") then
                    free = false
                    break
                end
            end
            if free then
                return node
            end
        end
        node = node.Parent
    end
    return nil
end

local constructParagraph = function(section, options)
    options = type(options) == "table" and options or {}
    local window = section.Window
    local touchMode = isTouchMode()
    local dims = measure(touchMode)
    local callback = options.Callback
    local locked = options.Locked == true
    local titleKey = resolveName(options)
    local descriptionKey = options.Description ~= nil and tostring(options.Description) or ""
    local pageTitleKey = options.PageTitle ~= nil and tostring(options.PageTitle) or nil
    local thumbImage = resolveImage(options.Image or options.Thumbnail)
    local pageImage = resolveImage(options.PageImage)
    local style = resolveStyle(options.Style or options.Mode, thumbImage ~= nil)
    local blocks = normalizeContent(options.Content or options.Text)
    local opened = false
    local animationToken = 0
    local hovering = false
    local target = nil
    local host = nil
    local clipper = nil
    local page = nil
    local pageTitle = nil
    local backLabel = nil
    local body = nil
    local watchers = {}
    local openedSignal = newSignal()
    local closedSignal = newSignal()

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

    local card = create("TextButton", {
        Size = UDim2.new(1, 0, 0, dims.Row),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = ""
    }, row)
    addCorner(card, 6)
    addStroke(card, Theme.Line, 1)
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

    local thumb = create("ImageLabel", {
        Size = UDim2.new(0, dims.Thumb, 0, dims.Thumb),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Image = "",
        ScaleType = Enum.ScaleType.Crop,
        Visible = false,
        LayoutOrder = 1
    }, card)
    addCorner(thumb, 6)
    addStroke(thumb, Theme.Line, 1)
    local thumbGradient = create("UIGradient", {
        Color = ColorSequence.new(Theme.Line, Theme.LineActive),
        Rotation = 45
    }, thumb)

    local textBlock = create("Frame", {
        Size = UDim2.new(1, -22, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 2
    }, card)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2)
    }, textBlock)

    local titleLabel = createLabel(textBlock, translateText(section, titleKey), 0)
    titleLabel.Size = UDim2.new(1, 0, 0, 16)
    titleLabel.LayoutOrder = 1

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

    local arrow = create("Frame", {
        Size = UDim2.new(0, 12, 0, 12),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 3
    }, card)
    local arrowTop = create("Frame", {
        Size = UDim2.new(0, 8, 0, 2),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, -1, 0.5, -3),
        Rotation = 45,
        BackgroundColor3 = Theme.TextSecondary,
        BorderSizePixel = 0
    }, arrow)
    local arrowBottom = create("Frame", {
        Size = UDim2.new(0, 8, 0, 2),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, -1, 0.5, 3),
        Rotation = -45,
        BackgroundColor3 = Theme.TextSecondary,
        BorderSizePixel = 0
    }, arrow)
    addCorner(arrowTop, 1)
    addCorner(arrowBottom, 1)

    local isLocked = function()
        return locked
    end

    card.MouseEnter:Connect(function()
        hovering = true
        if isLocked() then
            return
        end
        tween(card, Tweens.Hover, { BackgroundColor3 = Theme.LineActive })
    end)
    card.MouseLeave:Connect(function()
        hovering = false
        tween(card, Tweens.Hover, { BackgroundColor3 = Theme.Card })
    end)
    card.InputBegan:Connect(function(input)
        if isLocked() then
            return
        end
        if isPointerInput(input) then
            tween(card, Tweens.Hover, { BackgroundColor3 = PressedColor })
        end
    end)
    card.InputEnded:Connect(function(input)
        if isPointerInput(input) then
            local isTouch = input.UserInputType == Enum.UserInputType.Touch
            local color = (hovering and not isTouch) and Theme.LineActive or Theme.Card
            tween(card, Tweens.Hover, { BackgroundColor3 = color })
        end
    end)

    local applyZIndex = function()
        if not clipper then
            return
        end
        clipper.ZIndex = BaseZIndex
        for _, item in ipairs(clipper:GetDescendants()) do
            if item:IsA("GuiObject") then
                local depth = 0
                local node = item
                while node and node ~= clipper do
                    depth = depth + 1
                    node = node.Parent
                end
                item.ZIndex = BaseZIndex + depth
            end
        end
    end

    local syncPage = function()
        if not clipper or not target or not host or not target.Parent then
            return
        end
        local hostSize = host.AbsoluteSize
        if hostSize.X <= 0 or hostSize.Y <= 0 then
            return
        end
        local hostPosition = host:IsA("GuiObject") and host.AbsolutePosition or Vector2.zero
        local relative = target.AbsolutePosition - hostPosition
        local size = target.AbsoluteSize
        clipper.Position = UDim2.fromScale(relative.X / hostSize.X, relative.Y / hostSize.Y)
        clipper.Size = UDim2.fromScale(size.X / hostSize.X, size.Y / hostSize.Y)
    end

    local buildContent = function()
        if not body then
            return
        end
        for _, child in ipairs(body:GetChildren()) do
            if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                child:Destroy()
            end
        end
        local order = 0
        local bannerImage = pageImage
        if bannerImage == nil and style == "Thumbnail" then
            bannerImage = thumbImage
        end
        if bannerImage then
            order = order + 1
            local banner = create("ImageLabel", {
                Size = UDim2.new(1, 0, 0, dims.Banner),
                BackgroundColor3 = Theme.Card,
                BorderSizePixel = 0,
                Image = bannerImage,
                ScaleType = Enum.ScaleType.Crop,
                LayoutOrder = order
            }, body)
            addCorner(banner, 8)
        end
        if descriptionKey ~= "" then
            order = order + 1
            create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Text = translateText(section, descriptionKey),
                TextColor3 = Theme.TextSecondary,
                TextSize = dims.Small + 1,
                Font = Enum.Font.GothamMedium,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                LayoutOrder = order
            }, body)
        end
        for _, block in ipairs(blocks) do
            if block.Image then
                order = order + 1
                local image = create("ImageLabel", {
                    Size = UDim2.new(1, 0, 0, block.Height or dims.Banner),
                    BackgroundColor3 = Theme.Card,
                    BorderSizePixel = 0,
                    Image = block.Image,
                    ScaleType = Enum.ScaleType.Crop,
                    LayoutOrder = order
                }, body)
                addCorner(image, 8)
            end
            if block.Header then
                order = order + 1
                create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Text = translateText(section, block.Header),
                    TextColor3 = Theme.TextPrimary,
                    TextSize = dims.Text + 2,
                    Font = Enum.Font.GothamBold,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    LayoutOrder = order
                }, body)
            end
            if block.Text then
                order = order + 1
                create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Text = translateText(section, block.Text),
                    TextColor3 = Theme.TextSecondary,
                    TextSize = dims.Text,
                    Font = Enum.Font.Gotham,
                    RichText = true,
                    TextWrapped = true,
                    LineHeight = 1.15,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    LayoutOrder = order
                }, body)
            end
        end
        applyZIndex()
    end

    local applyPageTexts = function()
        if not page then
            return
        end
        local key = pageTitleKey or titleKey
        pageTitle.Text = translateText(section, key)
        backLabel.Text = translateText(section, "Back")
    end

    local ensurePage = function()
        if page then
            return true
        end
        local scroll = row:FindFirstAncestorWhichIsA("ScrollingFrame")
        target = scroll or section.Frame
        host = findHost(target)
        if not host then
            return false
        end
        clipper = create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Visible = false,
            ZIndex = BaseZIndex
        }, host)
        page = create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Theme.Background or Theme.Card,
            BorderSizePixel = 0,
            Active = true
        }, clipper)

        local topbar = create("Frame", {
            Size = UDim2.new(1, 0, 0, dims.Top),
            BackgroundTransparency = 1,
            BorderSizePixel = 0
        }, page)

        pageTitle = create("TextLabel", {
            Size = UDim2.new(1, -176, 1, 0),
            Position = UDim2.new(0, 88, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            TextColor3 = Theme.TextPrimary,
            TextSize = dims.Text + 1,
            Font = Enum.Font.GothamBold,
            TextTruncate = Enum.TextTruncate.AtEnd
        }, topbar)

        local back = create("TextButton", {
            Size = UDim2.new(0, 80, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = ""
        }, topbar)
        create("UIPadding", {
            PaddingLeft = UDim.new(0, 12)
        }, back)
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 6)
        }, back)
        local backArrow = create("Frame", {
            Size = UDim2.new(0, 12, 0, 12),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = 1
        }, back)
        local backTop = create("Frame", {
            Size = UDim2.new(0, 8, 0, 2),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 1, 0.5, -3),
            Rotation = -45,
            BackgroundColor3 = Theme.TextPrimary,
            BorderSizePixel = 0
        }, backArrow)
        local backBottom = create("Frame", {
            Size = UDim2.new(0, 8, 0, 2),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 1, 0.5, 3),
            Rotation = 45,
            BackgroundColor3 = Theme.TextPrimary,
            BorderSizePixel = 0
        }, backArrow)
        addCorner(backTop, 1)
        addCorner(backBottom, 1)
        backLabel = create("TextLabel", {
            Size = UDim2.new(0, 40, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            TextColor3 = Theme.TextPrimary,
            TextSize = dims.Text,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 2
        }, back)

        create("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 0, dims.Top),
            BackgroundColor3 = Theme.Line,
            BorderSizePixel = 0
        }, page)

        body = create("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, -(dims.Top + 1)),
            Position = UDim2.new(0, 0, 0, dims.Top + 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollBarThickness = touchMode and 5 or 3,
            ScrollBarImageColor3 = Theme.LineActive
        }, page)
        create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 10)
        }, body)
        create("UIPadding", {
            PaddingTop = UDim.new(0, 12),
            PaddingBottom = UDim.new(0, 12),
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12)
        }, body)

        back.Activated:Connect(function()
            object:Close()
        end)

        applyPageTexts()
        buildContent()
        return true
    end

    local disconnectWatchers = function()
        for _, connection in ipairs(watchers) do
            connection:Disconnect()
        end
        table.clear(watchers)
    end

    local closePage
    local connectWatchers = function()
        disconnectWatchers()
        local node = row
        while node do
            if node:IsA("GuiObject") then
                local watched = node
                watchers[#watchers + 1] = watched:GetPropertyChangedSignal("Visible"):Connect(function()
                    if not watched.Visible then
                        closePage(true)
                    end
                end)
            end
            node = node.Parent
        end
        if target then
            watchers[#watchers + 1] = target:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncPage)
            watchers[#watchers + 1] = target:GetPropertyChangedSignal("AbsolutePosition"):Connect(syncPage)
        end
        if host then
            watchers[#watchers + 1] = host:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncPage)
        end
    end

    closePage = function(instant)
        if not opened then
            return
        end
        opened = false
        disconnectWatchers()
        animationToken = animationToken + 1
        local token = animationToken
        if instant == true then
            page.Position = UDim2.new(1, 0, 0, 0)
            clipper.Visible = false
        else
            tween(page, Tweens.Hover, { Position = UDim2.new(1, 0, 0, 0) })
            task.delay(readDuration() + 0.05, function()
                if token ~= animationToken or opened or not clipper then
                    return
                end
                clipper.Visible = false
            end)
        end
        closedSignal:Fire()
        safeCall(callback, false)
    end

    local openPage = function()
        if opened or locked then
            return
        end
        if not ensurePage() then
            report("Warning", "Paragraph", "No host found for the page")
            return
        end
        opened = true
        animationToken = animationToken + 1
        syncPage()
        applyPageTexts()
        buildContent()
        clipper.Visible = true
        page.Position = UDim2.new(1, 0, 0, 0)
        tween(page, Tweens.Hover, { Position = UDim2.new(0, 0, 0, 0) })
        connectWatchers()
        openedSignal:Fire()
        safeCall(callback, true)
    end

    local applyCard = function()
        local hasThumb = style == "Thumbnail"
        thumb.Visible = hasThumb
        thumb.Size = UDim2.new(0, dims.Thumb, 0, dims.Thumb)
        thumb.Image = thumbImage or ""
        thumb.ImageTransparency = thumbImage and 0 or 1
        thumb.BackgroundTransparency = thumbImage and 1 or 0
        thumbGradient.Enabled = thumbImage == nil
        local minHeight = hasThumb and (dims.Thumb + 16) or dims.Row
        card.Size = UDim2.new(1, 0, 0, minHeight)
        local used = (hasThumb and dims.Thumb or 0) + 12 + (hasThumb and 20 or 10)
        textBlock.Size = UDim2.new(1, -used, 0, 0)
        descriptionLabel.TextSize = dims.Small
    end

    local applyTexts = function()
        local title = titleKey == "" and "" or translateText(section, titleKey)
        local description = descriptionKey == "" and "" or translateText(section, descriptionKey)
        titleLabel.Text = title
        titleLabel.Visible = title ~= ""
        descriptionLabel.Text = description
        descriptionLabel.Visible = description ~= ""
        applyPageTexts()
    end

    local applyLock = function()
        local fade = locked and LockedFade or 0
        card.BackgroundTransparency = fade
        titleLabel.TextTransparency = fade
        descriptionLabel.TextTransparency = fade
        thumb.ImageTransparency = thumbImage and fade or 1
        arrowTop.BackgroundTransparency = fade
        arrowBottom.BackgroundTransparency = fade
        if locked then
            closePage(true)
        end
    end

    local applyLayout = function()
        touchMode = isTouchMode()
        dims = measure(touchMode)
        applyCard()
        if page then
            body.ScrollBarThickness = touchMode and 5 or 3
            buildContent()
        end
    end

    section:Connect(card.Activated, function()
        if locked then
            return
        end
        if opened then
            closePage(false)
        else
            openPage()
        end
    end)

    section:Connect(UserInputService.InputBegan, function(input)
        if opened and input.KeyCode == Enum.KeyCode.Escape then
            closePage(false)
        end
    end)

    section:Connect(UserInputService.LastInputTypeChanged, function()
        if isTouchMode() ~= touchMode then
            applyLayout()
        end
    end)

    function object:Open()
        openPage()
    end

    function object:Close()
        closePage(false)
    end

    function object:ToggleOpen()
        if opened then
            closePage(false)
        else
            openPage()
        end
    end

    function object:IsOpen()
        return opened
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
        buildContent()
    end

    function object:GetDescription()
        return descriptionKey
    end

    function object:SetPageTitle(text)
        pageTitleKey = text ~= nil and tostring(text) or nil
        applyPageTexts()
    end

    function object:SetStyle(value)
        style = resolveStyle(value, thumbImage ~= nil)
        applyCard()
        buildContent()
    end

    function object:GetStyle()
        return style
    end

    function object:SetImage(value)
        thumbImage = resolveImage(value)
        applyCard()
        applyLock()
        buildContent()
    end

    function object:SetPageImage(value)
        pageImage = resolveImage(value)
        buildContent()
    end

    function object:SetContent(value)
        blocks = normalizeContent(value)
        buildContent()
    end

    function object:AddParagraph(text)
        blocks[#blocks + 1] = { Text = tostring(text or "") }
        buildContent()
    end

    function object:AddSection(header, text, image)
        blocks[#blocks + 1] = {
            Header = header ~= nil and tostring(header) or nil,
            Text = text ~= nil and tostring(text) or nil,
            Image = resolveImage(image)
        }
        buildContent()
    end

    function object:ClearContent()
        table.clear(blocks)
        buildContent()
    end

    function object:SetCallback(newCallback)
        if type(newCallback) == "function" then
            callback = newCallback
        end
    end

    function object:OnOpened(listener)
        return openedSignal:Connect(listener)
    end

    function object:OnClosed(listener)
        return closedSignal:Connect(listener)
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
            closePage(true)
        end
    end

    function object:Update(values)
        if type(values) ~= "table" then
            report("Warning", "Paragraph", "Update needs a table")
            return false
        end
        local newName = values.Name or values.Title
        if newName ~= nil then
            titleKey = tostring(newName)
        end
        if values.Description ~= nil then
            descriptionKey = tostring(values.Description)
        end
        if values.PageTitle ~= nil then
            pageTitleKey = tostring(values.PageTitle)
        end
        if type(values.Callback) == "function" then
            callback = values.Callback
        end
        local newImage = values.Image
        if newImage == nil then
            newImage = values.Thumbnail
        end
        if newImage ~= nil then
            thumbImage = resolveImage(newImage)
        end
        if values.PageImage ~= nil then
            pageImage = resolveImage(values.PageImage)
        end
        local newContent = values.Content
        if newContent == nil then
            newContent = values.Text
        end
        if newContent ~= nil then
            blocks = normalizeContent(newContent)
        end
        local newStyle = values.Style or values.Mode
        if newStyle ~= nil then
            style = resolveStyle(newStyle, thumbImage ~= nil)
        end
        if values.Locked ~= nil then
            locked = values.Locked == true
        end
        if values.Visible ~= nil then
            object:SetVisible(values.Visible)
        end
        applyCard()
        applyTexts()
        applyLock()
        buildContent()
        return true
    end

    function object:Refresh()
        applyLayout()
        applyTexts()
        applyLock()
    end

    function object:Destroy()
        closePage(true)
        disconnectWatchers()
        openedSignal:Clear()
        closedSignal:Clear()
        if clipper then
            clipper:Destroy()
        end
        row:Destroy()
    end

    object:Refresh()
    onLanguage(section, function()
        applyTexts()
        buildContent()
    end)

    return object
end

MiniElements.Register("Paragraph", function(section, options)
    local ok, result = pcall(constructParagraph, section, options)
    if not ok then
        warn("[Paragraph] " .. tostring(result))
        error(result, 0)
    end
    return result
end)