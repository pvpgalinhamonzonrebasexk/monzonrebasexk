local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local FONT = Enum.Font.BuilderSans
local FONT_BOLD = Enum.Font.BuilderSansBold

local env = getgenv and getgenv() or _G
local BASE_URL = "https://raw.githubusercontent.com/pvpgalinhamonzonrebasexk/monzonrebasexk/refs/heads/main/"
local FEATURES_SOURCE = "https://github.com/pvpgalinhamonzonrebasexk/monzonrebasexk/tree/main/Features"
local ELEMENTS_SOURCE = "https://github.com/pvpgalinhamonzonrebasexk/monzonrebasexk/tree/main/Library/Elements"
local NAME_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
local httpRequest = request or http_request or (syn and syn.request)

local baseEnvironment = (function()
    local ok, result = pcall(function()
        return getfenv(1)
    end)
    if ok and type(result) == "table" then
        return result
    end
    return env
end)()

local Theme = {
    Panel = Color3.fromRGB(20, 20, 20),
    HoverFill = Color3.fromRGB(255, 255, 255),
    TextPrimary = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(105, 105, 115),
    TextHeader = Color3.fromRGB(130, 130, 140),
    TitleText = Color3.fromRGB(255, 255, 255),
    Line = Color3.fromRGB(32, 32, 32),
    Accent = Color3.fromRGB(255, 255, 255)
}

local Metrics = {
    MinWidth = 320,
    MinHeight = 240,
    ScreenMargin = 24,
    TopBarHeight = 55,
    SectionGap = 10,
    ElementGap = 6,
    PagePadding = 12,
    TabWidthPC = 150,
    TabWidthMobile = 110,
    NarrowBreakpoint = 460,
    ShortBreakpoint = 320,
    PagePaddingShort = 6,
    PageSlide = 14
}

local Tweens = {
    Tab = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    Page = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    Hover = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
}

local IsMobile = function()
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end
local IS_MOBILE = IsMobile()

local isPointerInput = function(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local isMoveInput = function(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local loadRemote = function(url)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if ok and type(result) == "table" then
        return result
    end
    return nil
end

local loadRemoteBatch = function(urls)
    local results = {}
    local pending = #urls
    for index, url in ipairs(urls) do
        task.spawn(function()
            results[index] = loadRemote(url) or false
            pending = pending - 1
        end)
    end
    local startTime = os.clock()
    while pending > 0 and os.clock() - startTime < 20 do
        task.wait()
    end
    return results
end

local remotes = loadRemoteBatch({
    BASE_URL .. "Assets/Icons.luau",
    BASE_URL .. "Library/Notifications.luau"
})
local ICONS = remotes[1] or { assets = {} }
local Notifications = remotes[2] or nil
local Notify = Notifications and Notifications.Notify

if type(Notify) ~= "function" then
    Notify = function(options)
        local data = type(options) == "table" and options or { Description = options }
        warn("[Ecohub] " .. tostring(data.Title or "") .. " " .. tostring(data.Description or ""))
        return nil
    end
end

if Notifications then
    pcall(function()
        if Notifications.SetMaxVisible then
            Notifications.SetMaxVisible(IS_MOBILE and 3 or 5)
        end
        if Notifications.SetGroup then
            Notifications.SetGroup(true)
        end
        if type(Notifications.Config) == "table" then
            Notifications.Config.Width = IS_MOBILE and 260 or 320
        end
    end)
end

local Report = function(kind, title, text, id, duration)
    pcall(Notify, {
        Title = title,
        Description = text,
        Type = kind,
        Id = id,
        Duration = duration or (kind == "Error" and 7 or 4)
    })
end

local startProgress = function(title, text, id)
    local handle = nil
    pcall(function()
        handle = Notify({
            Title = title,
            Description = text,
            Type = "Info",
            Id = id,
            Duration = 0
        })
    end)
    local progress = {}
    function progress.update(newText)
        if type(handle) == "table" and handle.Update then
            pcall(handle.Update, { Description = newText })
        end
    end
    function progress.close()
        if type(handle) == "table" and handle.Close then
            pcall(handle.Close)
        end
    end
    return progress
end

local icon = function(name, fallback)
    return ICONS.assets and ICONS.assets["lucide-" .. name] or fallback or "rbxassetid://11419472304"
end

local getViewport = function()
    local camera = workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end
    return Vector2.new(1280, 720)
end

local setProperties = function(instance, properties)
    for property, value in pairs(properties) do
        instance[property] = value
    end
end

local create = function(className, properties, parent)
    local instance = Instance.new(className)
    setProperties(instance, properties)
    instance.Parent = parent
    return instance
end

local addCorner = function(parent, radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local addStroke = function(parent, color, thickness)
    return create("UIStroke", { Color = color, Thickness = thickness }, parent)
end

local addPadding = function(parent, top, bottom, left, right)
    return create("UIPadding", {
        PaddingTop = UDim.new(0, top),
        PaddingBottom = UDim.new(0, bottom),
        PaddingLeft = UDim.new(0, left),
        PaddingRight = UDim.new(0, right)
    }, parent)
end

local addList = function(parent, gap)
    return create("UIListLayout", {
        Padding = UDim.new(0, gap),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, parent)
end

local activeTweens = setmetatable({}, { __mode = "k" })

local cancelTween = function(instance)
    local running = activeTweens[instance]
    if running then
        running:Cancel()
        activeTweens[instance] = nil
    end
end

local tween = function(instance, info, goal)
    cancelTween(instance)
    local running = TweenService:Create(instance, info, goal)
    activeTweens[instance] = running
    running:Play()
    return running
end

local animate = function(instance, info, goal, instant)
    if instant then
        cancelTween(instance)
        setProperties(instance, goal)
        return
    end
    tween(instance, info, goal)
end

local Bypass = { Hooked = false, Chunks = {} }

function Bypass:RandomName()
    local characters = {}
    for index = 1, math.random(8, 14) do
        local position = math.random(1, #NAME_CHARS)
        characters[index] = NAME_CHARS:sub(position, position)
    end
    return table.concat(characters)
end

function Bypass:GetParent()
    if syn and syn.protect_gui then
        return game:GetService("CoreGui")
    end
    if gethui then
        return gethui()
    end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

function Bypass:PlaceGui(gui)
    if not gui then
        return
    end
    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(gui)
        end
        gui.Parent = Bypass:GetParent()
    end)
    if not gui.Parent then
        gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
end

function Bypass:HideObject(object)
    if not object then
        return
    end
    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(object, "Archivable", false)
        end
        if makereadonly then
            makereadonly(object)
        elseif setreadonly then
            setreadonly(object, true)
        end
    end)
end

function Bypass:HookDetections()
    if Bypass.Hooked then
        return
    end
    Bypass.Hooked = true
    if setthreadidentity then
        pcall(setthreadidentity, 8)
    end
    if setstackhidden then
        pcall(setstackhidden, Bypass.HookDetections, true)
    end
    local callerCheck = checkcaller
    local wrapClosure = newcclosure or function(fn)
        return fn
    end
    local detectionNames = { "getscripts", "getloadedmodules", "getrunningscripts", "getnilinstances", "filtergc", "getinstances" }
    for _, functionName in ipairs(detectionNames) do
        pcall(function()
            local target = env[functionName] or _G[functionName]
            if not target then
                return
            end
            if iscclosure and iscclosure(target) then
                if oth and oth.hook then
                    oth.hook(target, function()
                        return {}
                    end)
                end
            elseif hookfunction then
                local original
                original = hookfunction(target, wrapClosure(function(...)
                    if callerCheck and callerCheck() then
                        return original(...)
                    end
                    return {}
                end))
            end
        end)
    end
    if hookfunction and isourthread and debug and debug.getinfo then
        pcall(function()
            local originalGetInfo
            originalGetInfo = hookfunction(debug.getinfo, wrapClosure(function(level, ...)
                if type(level) == "thread" and isourthread(level) then
                    return nil
                end
                return originalGetInfo(level, ...)
            end))
        end)
    end
    if hookfunction and debug and debug.getcallstack then
        pcall(function()
            local originalCallStack
            originalCallStack = hookfunction(debug.getcallstack, wrapClosure(function(...)
                local stack = originalCallStack(...)
                if type(stack) ~= "table" then
                    return stack
                end
                local clean = {}
                for _, entry in ipairs(stack) do
                    if entry.what ~= "executor" then
                        clean[#clean + 1] = entry
                    end
                end
                return clean
            end))
        end)
    end
end

function Bypass:Init()
    local ok, err = pcall(Bypass.HookDetections, Bypass)
    if not ok then
        Report("Error", "Ecohub | Bypass", tostring(err), "bypass", 6)
    end
end

function Bypass:Validate(body)
    if type(body) ~= "string" then
        return false, "invalid response"
    end
    local size = #body
    if size == 0 then
        return false, "empty file"
    end
    if size > 4000000 then
        return false, "file too large"
    end
    local head = body:sub(1, 64):lower()
    if head:find("^%s*<!doctype") or head:find("^%s*<html") then
        return false, "html page"
    end
    if head:sub(1, 3) == "404" then
        return false, "not found"
    end
    return true
end

function Bypass:Compile(source, displayName)
    local chunkName = Bypass:RandomName()
    local fn, compileError = loadstring(source, "=" .. chunkName)
    Bypass.Chunks[chunkName] = displayName
    return fn, compileError
end

function Bypass:Resolve(message)
    local text = tostring(message)
    local chunkName = text:match("^([%w_%-]+):%d+:")
    local displayName = chunkName and Bypass.Chunks[chunkName]
    if displayName then
        return displayName .. text:sub(#chunkName + 1)
    end
    return text
end

local ELEMENT_METHODS = {
    CreateToggle = "Checkbox",
    CreateButton = "Button",
    CreateSlider = "Slider",
    CreateDropdown = "Dropdown",
    CreateColorPicker = "ColorPicker",
    CreateParagraph = "Paragraph"
}

local ELEMENT_FALLBACK = { "Checkbox", "Button", "Slider", "Dropdown", "ColorPicker", "Paragraph" }

local Elements = {
    List = {},
    Files = {},
    _searchRegistry = {},
    _searchSet = {},
    _sections = setmetatable({}, { __mode = "k" })
}

function Elements.Register(name, constructor)
    if type(name) ~= "string" or type(constructor) ~= "function" then
        return
    end
    Elements.List[name] = constructor
end

function Elements.RegisterSearchEntry(labelText, frame, sectionFrame)
    if type(labelText) ~= "string" or labelText == "" or typeof(frame) ~= "Instance" then
        return
    end
    local set = Elements._searchSet
    if set[frame] then
        return
    end
    local ancestor = frame.Parent
    while ancestor do
        if set[ancestor] then
            return
        end
        ancestor = ancestor.Parent
    end
    local registry = Elements._searchRegistry
    for index = #registry, 1, -1 do
        local existing = registry[index].frame
        if existing:IsDescendantOf(frame) then
            set[existing] = nil
            table.remove(registry, index)
        end
    end
    local entry = { label = labelText:lower(), frame = frame, section = sectionFrame }
    set[frame] = entry
    registry[#registry + 1] = entry
    frame.Destroying:Connect(function()
        set[frame] = nil
        local position = table.find(registry, entry)
        if position then
            table.remove(registry, position)
        end
    end)
end

local protectOptions = function(options, label)
    if type(options) ~= "table" then
        return options
    end
    local copy = {}
    for key, value in pairs(options) do
        copy[key] = value
    end
    for _, callbackKey in ipairs({ "Callback", "callback" }) do
        local callback = copy[callbackKey]
        if type(callback) == "function" then
            copy[callbackKey] = function(...)
                local ok, result = pcall(callback, ...)
                if not ok then
                    Report("Error", "Ecohub | " .. label, Bypass:Resolve(result), "callback:" .. label, 6)
                    return nil
                end
                return result
            end
        end
    end
    return copy
end

local Library = {}
Library.__index = Library

Library.Bypass = Bypass
Library.Notify = Notify
Library.Notifications = Notifications
Library.Report = Report
Library.ICONS = ICONS
Library.Elements = Elements
Library.Theme = Theme
Library.Metrics = Metrics
Library.Tweens = Tweens
Library.Tween = tween
Library.Animate = animate
Library.FONT = FONT
Library.FONT_BOLD = FONT_BOLD
Library.IsMobile = IsMobile
Library.GetIcon = icon
Library.GetViewport = getViewport
Library.Features = {}

local treeStore = type(env.__EcohubTrees) == "table" and env.__EcohubTrees or {}
env.__EcohubTrees = treeStore

local featureState = { miss = {} }
local featureConfig = {
    TreeTtl = 60,
    TreeRetry = 30,
    MissTtl = 10,
    Retries = 3,
    RetryDelay = 0.3,
    MaxParallel = IS_MOBILE and 3 or 6,
    Timeout = 30,
    StartTimeout = 2
}
Library.FeatureConfig = featureConfig

local featuresSource = nil
local elementsSource = nil
local triedElements = {}

local stripExtension = function(path)
    return (path:gsub("%.luau$", ""):gsub("%.lua$", ""))
end

local encodePath = function(path)
    return (path:gsub("[^%w%-_%.~/]", function(character)
        return string.format("%%%02X", character:byte())
    end))
end

local cacheBust = function(url, salt)
    return url .. (url:find("?", 1, true) and "&" or "?") .. "cb=" .. os.time() .. "_" .. salt
end

local newSource = function(url)
    local owner, repoName, branch, root = url:match("^https?://github%.com/([^/]+)/([^/]+)/tree/([^/]+)/?(.*)$")
    if not owner then
        return nil
    end
    root = root:gsub("/+$", "")
    local repo = owner .. "/" .. repoName
    local prefix = root ~= "" and (root .. "/") or ""
    return {
        Url = url,
        Repo = repo,
        Branch = branch,
        Root = root,
        Prefix = prefix,
        RawUrl = "https://raw.githubusercontent.com/" .. repo .. "/" .. branch .. "/" .. prefix,
        TreeApi = "https://api.github.com/repos/" .. repo .. "/git/trees/" .. branch .. "?recursive=1",
        Entries = nil,
        Stamp = -1
    }
end

function Library:SetFeaturesSource(url)
    local source = newSource(url)
    if not source then
        return false
    end
    featuresSource = source
    Library.FeaturesSource = url
    Library.FeaturesRepo = source.Repo
    Library.FeaturesBranch = source.Branch
    Library.FeaturesRoot = source.Root
    Library.FeaturesUrl = source.RawUrl
    Library.FeaturesTreeApi = source.TreeApi
    return true
end

function Library:SetElementsSource(url)
    local source = newSource(url)
    if not source then
        return false
    end
    elementsSource = source
    Library.ElementsSource = url
    Library.ElementsUrl = source.RawUrl
    return true
end

Library:SetFeaturesSource(FEATURES_SOURCE)
Library:SetElementsSource(ELEMENTS_SOURCE)

local cleanFeatureName = function(name)
    name = name:gsub("\\", "/"):gsub("^%s+", ""):gsub("%s+$", "")
    name = name:gsub("^/+", ""):gsub("/+$", "")
    name = name:gsub("%.luau$", ""):gsub("%.lua$", "")
    local root = featuresSource.Root
    if root ~= "" then
        local prefix = root:lower() .. "/"
        if name:lower():sub(1, #prefix) == prefix then
            name = name:sub(#prefix + 1)
        end
    end
    return name
end

local fetchSource = function(url)
    local missTime = featureState.miss[url]
    if missTime and os.clock() - missTime < featureConfig.MissTtl then
        return nil, "not found"
    end
    local reason = "request failed"
    for attempt = 1, featureConfig.Retries do
        local target = cacheBust(url, attempt)
        local ok, body, status = pcall(function()
            if httpRequest then
                local response = httpRequest({
                    Url = target,
                    Method = "GET",
                    Headers = { ["User-Agent"] = "Mozilla/5.0", ["Cache-Control"] = "no-cache" }
                })
                if type(response) == "table" then
                    return response.Body, response.StatusCode or (response.Success and 200 or 0)
                end
                return nil, 0
            end
            return game:HttpGet(target), 200
        end)
        if ok and status == 200 then
            local valid, invalid = Bypass:Validate(body)
            if valid then
                return body
            end
            if invalid == "not found" then
                featureState.miss[url] = os.clock()
            end
            return nil, invalid
        end
        local message = tostring(body)
        if (ok and status == 404) or (not ok and message:find("404", 1, true)) then
            featureState.miss[url] = os.clock()
            return nil, "not found"
        end
        if (ok and (status == 403 or status == 429)) or (not ok and (message:find("403", 1, true) or message:find("429", 1, true))) then
            return nil, "rate limited"
        end
        if ok and type(status) == "number" and status >= 400 and status < 500 and status ~= 408 then
            return nil, "HTTP " .. status
        end
        reason = ok and (status == 0 and "no response" or ("HTTP " .. tostring(status))) or message
        if attempt < featureConfig.Retries then
            task.wait(featureConfig.RetryDelay * attempt)
        end
    end
    return nil, reason
end

local fetchAll = function(urls)
    local bodies = {}
    local reasons = {}
    local total = #urls
    if total == 0 then
        return bodies, reasons
    end
    local nextIndex = 0
    local finished = 0
    local workers = math.min(featureConfig.MaxParallel, total)
    for _ = 1, workers do
        task.spawn(function()
            while true do
                nextIndex = nextIndex + 1
                local index = nextIndex
                if index > total then
                    break
                end
                local url = urls[index]
                local ok, body, reason = pcall(fetchSource, url)
                if not ok then
                    reasons[url] = tostring(body)
                elseif body then
                    bodies[url] = body
                else
                    reasons[url] = reason or "unknown"
                end
            end
            finished = finished + 1
        end)
    end
    local startTime = os.clock()
    while finished < workers and os.clock() - startTime < featureConfig.Timeout do
        task.wait()
    end
    for _, url in ipairs(urls) do
        if not bodies[url] and not reasons[url] then
            local body, reason = fetchSource(url)
            if body then
                bodies[url] = body
            else
                reasons[url] = reason or "unknown"
            end
        end
    end
    return bodies, reasons
end

local refreshTree = function(source, force)
    local now = os.time()
    local store = treeStore[source.TreeApi]
    if not store then
        store = { entries = nil, time = 0, failedAt = nil, stamp = 0 }
        treeStore[source.TreeApi] = store
    end
    if not force then
        if store.entries and now - store.time < featureConfig.TreeTtl then
            return store
        end
        if store.failedAt and now - store.failedAt < featureConfig.TreeRetry then
            return store.entries and store or nil
        end
    end
    local body = fetchSource(source.TreeApi)
    local ok, data = false, nil
    if body then
        ok, data = pcall(HttpService.JSONDecode, HttpService, body)
    end
    if not ok or type(data) ~= "table" or type(data.tree) ~= "table" then
        store.failedAt = now
        return store.entries and store or nil
    end
    local entries = {}
    for _, node in ipairs(data.tree) do
        local path = node.path
        if node.type == "blob" and type(path) == "string" and (path:match("%.luau$") or path:match("%.lua$")) then
            entries[#entries + 1] = path
        end
    end
    store.entries = entries
    store.time = now
    store.failedAt = nil
    store.stamp = store.stamp + 1
    return store
end

local scopedEntries = function(source, force)
    local store = refreshTree(source, force)
    if not store then
        return nil
    end
    if source.Entries and source.Stamp == store.stamp then
        return source.Entries
    end
    local prefix = source.Prefix
    local prefixLength = #prefix
    local entries = {}
    local byKey = {}
    for _, path in ipairs(store.entries) do
        if path:sub(1, prefixLength) == prefix then
            local relative = path:sub(prefixLength + 1)
            if relative ~= "" then
                local key = stripExtension(relative)
                local lowerKey = key:lower()
                local entry = {
                    path = relative,
                    key = key,
                    lkey = lowerKey,
                    lpath = relative:lower(),
                    base = lowerKey:match("([^/]+)$")
                }
                local existing = byKey[lowerKey]
                if not existing then
                    byKey[lowerKey] = entry
                    entries[#entries + 1] = entry
                elseif relative:match("%.luau$") then
                    local position = table.find(entries, existing)
                    if position then
                        entries[position] = entry
                    end
                    byKey[lowerKey] = entry
                end
            end
        end
    end
    table.sort(entries, function(a, b)
        return a.lpath < b.lpath
    end)
    source.Entries = entries
    source.Stamp = store.stamp
    return entries
end

local matchFeatureFiles = function(entries, name)
    local lowered = name:lower()
    if lowered == "*" or lowered == "all" then
        return entries, "all"
    end
    local folderPrefix = lowered .. "/"
    local folderLength = #folderPrefix
    local direct = {}
    local base = {}
    local kind = "file"
    for _, entry in ipairs(entries) do
        if entry.lkey == lowered then
            direct[#direct + 1] = entry
        elseif entry.lpath:sub(1, folderLength) == folderPrefix then
            direct[#direct + 1] = entry
            kind = "folder"
        elseif entry.base == lowered then
            base[#base + 1] = entry
        end
    end
    if #direct > 0 then
        return direct, kind
    end
    return base, "name"
end

local featureCandidates = function(name)
    local list = {}
    local seen = {}
    for _, variant in ipairs({ name, name:upper(), name:lower() }) do
        local last = variant:match("([^/]+)$") or variant
        for _, path in ipairs({
            variant .. ".luau",
            variant .. ".lua",
            variant .. "/" .. last .. ".luau",
            variant .. "/init.luau"
        }) do
            if not seen[path] then
                seen[path] = true
                list[#list + 1] = path
            end
        end
    end
    return list
end

local buildTargets = function(item)
    if item:match("^https?://") then
        local short = item:match("([^/]+)%.luau?$") or item
        local rawUrl = (item:gsub("^https?://github%.com/([^/]+)/([^/]+)/blob/", "https://raw.githubusercontent.com/%1/%2/"))
        return { { key = short, urls = { rawUrl } } }
    end
    local name = cleanFeatureName(item)
    if name == "" then
        return nil, "LoadFeature needs a name or link"
    end
    local isAll = name == "*" or name:lower() == "all"
    local entries = scopedEntries(featuresSource, false)
    if entries then
        local matches, kind = matchFeatureFiles(entries, name)
        if #matches == 0 then
            entries = scopedEntries(featuresSource, true) or entries
            matches, kind = matchFeatureFiles(entries, name)
        end
        if #matches > 1 and kind == "name" then
            return nil, "Ambiguous name: " .. name .. ". Use folder/file, e.g. " .. matches[1].key
        end
        if #matches == 0 then
            return nil, isAll and "No features found in the folder" or ("Feature not found: " .. name)
        end
        local targets = {}
        for _, entry in ipairs(matches) do
            targets[#targets + 1] = {
                key = entry.key,
                urls = { featuresSource.RawUrl .. encodePath(entry.path) }
            }
        end
        return targets, nil, name
    end
    if isAll then
        return nil, "GitHub index unavailable, cannot load all features"
    end
    Report("Warning", "Ecohub | API", "GitHub index unavailable, using direct links", "api:index", 5)
    local urls = {}
    for _, candidate in ipairs(featureCandidates(name)) do
        urls[#urls + 1] = featuresSource.RawUrl .. encodePath(candidate)
    end
    return { { key = name, urls = urls, fallback = true } }
end

local isWindow = function(target)
    return target ~= Library and type(target) == "table" and type(target.tabs) == "table"
end

function Library:RefreshFeatures()
    return scopedEntries(featuresSource, true) ~= nil
end

function Library:ListFeatures()
    local entries = scopedEntries(featuresSource, false)
    local list = {}
    if entries then
        for _, entry in ipairs(entries) do
            list[#list + 1] = entry.key
        end
    end
    return list
end

function Library:GetLoadedFeatures()
    local list = {}
    if type(self.loadedFeatures) == "table" then
        for key in pairs(self.loadedFeatures) do
            list[#list + 1] = key
        end
    end
    table.sort(list)
    return list
end

function Library:_exposeGlobals()
    env.Windows = self
    env.Window = self
    env.Library = Library
    env.Librarys = Library
end

function Library:_runFeature(source, name)
    local fn, compileError = Bypass:Compile(source, name)
    if not fn then
        Report("Error", "Ecohub | " .. name, Bypass:Resolve(compileError), "feature:" .. name, 8)
        return false
    end
    self:_exposeGlobals()
    local run = { done = false, ok = true }
    task.spawn(function()
        if setthreadidentity then
            pcall(setthreadidentity, 8)
        end
        local ok, runError = pcall(fn)
        run.ok = ok
        run.done = true
        if not ok then
            Report("Error", "Ecohub | " .. name, Bypass:Resolve(runError), "feature:" .. name, 8)
        end
    end)
    local started = os.clock()
    while not run.done and os.clock() - started < featureConfig.StartTimeout do
        task.wait()
    end
    if run.done and not run.ok then
        return false
    end
    Library.Features[name] = true
    return true
end

function Library:UnloadFeature(nameOrKey)
    if not isWindow(self) then
        Report("Error", "Ecohub | API", "Use Window:UnloadFeature(...), not Librarys:UnloadFeature(...)", "api:caller", 6)
        return false
    end
    local lowered = cleanFeatureName(tostring(nameOrKey)):lower()
    local keys = {}
    for key in pairs(self.loadedFeatures) do
        local lowerKey = key:lower()
        local baseKey = lowerKey:match("([^/]+)$")
        if lowerKey == lowered or baseKey == lowered or lowerKey:sub(1, #lowered + 1) == lowered .. "/" then
            keys[#keys + 1] = key
        end
    end
    if #keys == 0 then
        return false
    end
    for _, key in ipairs(keys) do
        local base = key:match("([^/]+)$")
        local unload = env[base .. "Unload"]
        if type(unload) == "function" then
            local ok, unloadError = pcall(unload)
            if not ok then
                Report("Error", "Ecohub | " .. key, Bypass:Resolve(unloadError), "unload:" .. key, 6)
            end
        end
        self.loadedFeatures[key] = nil
        Library.Features[key] = nil
    end
    return true
end

function Library:_unloadAll()
    local keys = {}
    for key in pairs(self.loadedFeatures) do
        keys[#keys + 1] = key
    end
    for _, key in ipairs(keys) do
        pcall(self.UnloadFeature, self, key)
    end
end

function Library:_loadItems(list, options)
    options = type(options) == "table" and options or {}
    local results = {}
    local plans = {}
    local urlSet = {}
    local urlList = {}
    local totalTargets = 0
    for _, item in ipairs(list) do
        if type(item) ~= "string" or item == "" then
            Report("Error", "Ecohub | API", "LoadFeature needs a name or link", "api:name", 5)
        else
            local targets, err, group = buildTargets(item)
            if not targets then
                Report("Error", "Ecohub | API", err, "api:" .. item, 6)
                results[item] = false
            else
                plans[#plans + 1] = { item = item, targets = targets, group = group }
                for _, target in ipairs(targets) do
                    if options.Reload and self.loadedFeatures[target.key] then
                        self:UnloadFeature(target.key)
                    end
                    if not self.loadedFeatures[target.key] then
                        totalTargets = totalTargets + 1
                        if not target.fallback then
                            local url = target.urls[1]
                            if not urlSet[url] then
                                urlSet[url] = true
                                urlList[#urlList + 1] = url
                            end
                        end
                    end
                end
            end
        end
    end
    if #plans == 0 then
        return results
    end
    local progress = nil
    if totalTargets > 0 then
        progress = startProgress("Ecohub | Features", "Downloading " .. totalTargets .. " file(s)...", "features:progress")
    end
    local loadedNow = 0
    local failedNow = 0
    local current = 0
    local failedNames = {}
    local ok, loopError = pcall(function()
        local bodies, reasons = fetchAll(urlList)
        for _, plan in ipairs(plans) do
            local loaded = 0
            for _, target in ipairs(plan.targets) do
                if self.loadedFeatures[target.key] then
                    loaded = loaded + 1
                else
                    current = current + 1
                    local source = nil
                    local reason = nil
                    if target.fallback then
                        for _, url in ipairs(target.urls) do
                            source, reason = fetchSource(url)
                            if source then
                                break
                            end
                        end
                    else
                        source = bodies[target.urls[1]]
                        reason = reasons[target.urls[1]]
                    end
                    if source then
                        if progress then
                            progress.update("Loading " .. target.key .. " (" .. current .. "/" .. totalTargets .. ")")
                        end
                        if self:_runFeature(source, target.key) then
                            self.loadedFeatures[target.key] = true
                            loaded = loaded + 1
                            loadedNow = loadedNow + 1
                        else
                            failedNow = failedNow + 1
                            failedNames[#failedNames + 1] = target.key
                        end
                        source = nil
                    else
                        failedNow = failedNow + 1
                        local why = target.fallback and "not found, index unavailable" or tostring(reason or "unknown")
                        failedNames[#failedNames + 1] = target.key .. " (" .. why .. ")"
                    end
                end
            end
            if loaded > 0 and plan.group then
                Library.Features[plan.group] = true
            end
            results[plan.item] = loaded > 0
        end
        table.clear(bodies)
    end)
    if progress then
        progress.close()
    end
    if not ok then
        Report("Error", "Ecohub | API", Bypass:Resolve(loopError), "api:loop", 8)
    end
    if loadedNow > 0 and failedNow == 0 then
        Report("Success", "Ecohub | Features", "Loaded " .. loadedNow .. " feature(s)", "features:done", 3)
    elseif failedNow > 0 then
        Report(loadedNow > 0 and "Warning" or "Error", "Ecohub | Features", "Loaded " .. loadedNow .. ", failed " .. failedNow .. ": " .. table.concat(failedNames, ", "), "features:done", 6)
    end
    return results
end

function Library:LoadFeature(nameOrUrl, options)
    if not isWindow(self) then
        Report("Error", "Ecohub | API", "Use Window:LoadFeature(...), not Librarys:LoadFeature(...)", "api:caller", 6)
        return false
    end
    return self:_loadItems({ nameOrUrl }, options)[nameOrUrl] == true
end

function Library:LoadFeatures(list, options)
    if type(list) == "string" then
        list = { list }
    end
    list = type(list) == "table" and list or {}
    if not isWindow(self) then
        Report("Error", "Ecohub | API", "Use Window:LoadFeatures(...), not Librarys:LoadFeatures(...)", "api:caller", 6)
        local failed = {}
        for _, item in ipairs(list) do
            failed[item] = false
        end
        return failed
    end
    return self:_loadItems(list, options)
end

function Library:LoadAllFeatures(options)
    if not isWindow(self) then
        Report("Error", "Ecohub | API", "Use Window:LoadAllFeatures(...), not Librarys:LoadAllFeatures(...)", "api:caller", 6)
        return {}
    end
    return self:_loadItems({ "all" }, options)
end

local elementGlobals = {
    Elements = Elements,
    Library = Library,
    Notify = Notify,
    Report = Report,
    Theme = Theme,
    Metrics = Metrics,
    FONT = FONT,
    FONT_BOLD = FONT_BOLD,
    TweenService = TweenService,
    UserInputService = UserInputService,
    Players = Players,
    HttpService = HttpService,
    ICONS = ICONS,
    Icon = icon
}
local elementEnvironment = setmetatable(elementGlobals, { __index = baseEnvironment })

local sandboxElement = function(fn)
    if setfenv then
        local ok = pcall(setfenv, fn, elementEnvironment)
        if ok then
            return
        end
    end
    for key, value in pairs(elementGlobals) do
        if env[key] == nil then
            env[key] = value
        end
    end
end

local runElement = function(source, key)
    local fn, compileError = Bypass:Compile(source, "Elements/" .. key)
    if not fn then
        Report("Error", "Ecohub | " .. key, Bypass:Resolve(compileError), "element:file:" .. key, 8)
        return false
    end
    sandboxElement(fn)
    local ok, runError = pcall(fn)
    if not ok then
        Report("Error", "Ecohub | " .. key, Bypass:Resolve(runError), "element:file:" .. key, 8)
        return false
    end
    Elements.Files[key] = true
    return true
end

function Library:LoadElements(force)
    local source = elementsSource
    local entries = scopedEntries(source, force == true)
    local targets = {}
    local urls = {}
    if entries then
        if #entries == 0 then
            Report("Warning", "Ecohub | Elements", "No elements found in the folder", "elements:empty", 6)
            return false
        end
        for _, entry in ipairs(entries) do
            if force or not Elements.Files[entry.key] then
                local url = source.RawUrl .. encodePath(entry.path)
                targets[#targets + 1] = { key = entry.key, url = url }
                urls[#urls + 1] = url
            end
        end
    else
        for _, name in ipairs(ELEMENT_FALLBACK) do
            if force or not Elements.Files[name] then
                local url = source.RawUrl .. name .. ".luau"
                targets[#targets + 1] = { key = name, url = url }
                urls[#urls + 1] = url
            end
        end
    end
    if #targets == 0 then
        return true
    end
    local bodies, reasons = fetchAll(urls)
    local loaded = 0
    local failed = {}
    for _, target in ipairs(targets) do
        local body = bodies[target.url]
        if body then
            if runElement(body, target.key) then
                loaded = loaded + 1
            else
                failed[#failed + 1] = target.key
            end
        elseif entries then
            failed[#failed + 1] = target.key .. " (" .. tostring(reasons[target.url] or "unknown") .. ")"
        end
    end
    table.clear(bodies)
    if not entries and loaded == 0 then
        Report("Error", "Ecohub | Elements", "GitHub index unavailable and no element could be loaded", "elements:none", 8)
        return false
    end
    if #failed > 0 then
        Report("Warning", "Ecohub | Elements", "Failed: " .. table.concat(failed, ", "), "elements:done", 6)
        return false
    end
    return true
end

function Library:_loadMissingElement(name)
    if Elements.List[name] or triedElements[name] then
        return Elements.List[name]
    end
    triedElements[name] = true
    local body = fetchSource(elementsSource.RawUrl .. encodePath(name) .. ".luau")
    if body then
        runElement(body, name)
    end
    return Elements.List[name]
end

function Library:ListElements()
    local list = {}
    for name in pairs(Elements.List) do
        list[#list + 1] = name
    end
    table.sort(list)
    return list
end

function Library:CreateWindow(config)
    config = type(config) == "table" and config or {}
    local window = setmetatable({}, Library)
    window.Title = config.Title or "UILib"
    window.SubTitle = config.SubTitle or config.Subtitle or ""
    local size = config.Size or UDim2.fromOffset(580, 460)
    window.BaseWidth = size.X.Offset
    window.BaseHeight = size.Y.Offset
    window.MinimizeKey = config.MinimizeKey or Enum.KeyCode.LeftControl
    window.IsMobile = IsMobile()
    window.tabs = {}
    window.sections = {}
    window.sectionIndexes = {}
    window.sectionCount = 0
    window.tabCounter = 0
    window.selectedTab = nil
    window.connections = {}
    window.minimized = false
    window.loadedFeatures = {}
    window.searchMoved = {}
    window.searchGroups = {}
    window.searchToken = 0
    window.appliedQuery = ""
    local previous = env.__EcohubWindow
    if previous and previous.Destroy then
        pcall(previous.Destroy, previous)
    end
    local ok, err = pcall(function()
        Bypass:Init()
        window:_init()
    end)
    local elementsOk, elementsError = pcall(Library.LoadElements, Library)
    if not elementsOk then
        Report("Error", "Ecohub | Elements", Bypass:Resolve(elementsError), "elements", 8)
    end
    if not ok then
        Report("Error", "Ecohub | Window", Bypass:Resolve(err), "window", 8)
    else
        Report("Success", "Ecohub", "Window loaded", "window", 3)
    end
    env.__EcohubWindow = window
    window:_exposeGlobals()
    return window
end

function Library.new(title, subtitle)
    return Library:CreateWindow({ Title = title, SubTitle = subtitle })
end

function Library:_computeSize()
    local viewport = getViewport()
    local maxWidth = math.max(Metrics.MinWidth, viewport.X - Metrics.ScreenMargin * 2)
    local maxHeight = math.max(Metrics.MinHeight, viewport.Y - Metrics.ScreenMargin * 2)
    return math.clamp(self.BaseWidth, Metrics.MinWidth, maxWidth), math.clamp(self.BaseHeight, Metrics.MinHeight, maxHeight)
end

function Library:_applySize()
    if not self.mainPanel then
        return
    end
    local width, height = self:_computeSize()
    self.mainPanel.Size = UDim2.new(0, width, 0, height)
    self:_applyLayoutMode()
end

function Library:_applyLayoutMode()
    if not self.mainPanel then
        return
    end
    local panelSize = self.mainPanel.AbsoluteSize
    local width = panelSize.X > 0 and panelSize.X or (self.currentWidth or self.BaseWidth)
    local height = panelSize.Y > 0 and panelSize.Y or (self.currentHeight or self.BaseHeight)
    self.currentWidth = width
    self.currentHeight = height
    local tabWidth = self.IsMobile and Metrics.TabWidthMobile or Metrics.TabWidthPC
    if width < Metrics.NarrowBreakpoint then
        tabWidth = Metrics.TabWidthMobile
    end
    local compact = height < Metrics.ShortBreakpoint
    if self.tabWidth == tabWidth and self.compact == compact then
        return
    end
    self.tabWidth = tabWidth
    self.compact = compact
    if self.tabBar then
        self.tabBar.Size = UDim2.new(0, tabWidth, 1, 0)
    end
    if self.tabDivider then
        self.tabDivider.Position = UDim2.new(0, tabWidth - 1, 0, 0)
    end
    if self.tabContent then
        self.tabContent.Size = UDim2.new(1, -tabWidth, 1, 0)
        self.tabContent.Position = UDim2.new(0, tabWidth, 0, 0)
    end
    for _, tab in ipairs(self.tabs) do
        if tab.relayout then
            tab.relayout()
        end
    end
end

function Library:_init()
    if not Players.LocalPlayer then
        return
    end
    table.clear(Elements._searchRegistry)
    table.clear(Elements._searchSet)
    self.screenGui = create("ScreenGui", {
        Name = Bypass:RandomName(),
        ResetOnSpawn = false,
        DisplayOrder = 999
    })
    Bypass:PlaceGui(self.screenGui)
    Bypass:HideObject(self.screenGui)
    local width, height = self:_computeSize()
    self.currentWidth = width
    self.currentHeight = height
    self.mainPanel = create("Frame", {
        Name = Bypass:RandomName(),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, width, 0, height),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        ClipsDescendants = true
    }, self.screenGui)
    Bypass:HideObject(self.mainPanel)
    addCorner(self.mainPanel, 8)
    addStroke(self.mainPanel, Theme.Line, 1)
    self:_createTopBar()
    self:_createContent()
    self:_setupDrag()
    self:_applyLayoutMode()
    table.insert(self.connections, self.mainPanel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        self:_applyLayoutMode()
    end))
    local camera = workspace.CurrentCamera
    if camera then
        table.insert(self.connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            self:_applySize()
        end))
    end
    if self.IsMobile then
        self:_createToggleButton()
    else
        self:_setupKeybind()
    end
end

function Library:SetMinimized(state)
    self.minimized = state
    if self.mainPanel then
        self.mainPanel.Visible = not state
    end
end

function Library:Toggle()
    self:SetMinimized(not self.minimized)
end

function Library:_setupKeybind()
    table.insert(self.connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end
        if input.KeyCode == self.MinimizeKey then
            self:Toggle()
        end
    end))
end

function Library:_createTopBar()
    self.topBar = create("Frame", {
        Name = Bypass:RandomName(),
        Size = UDim2.new(1, 0, 0, Metrics.TopBarHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5
    }, self.mainPanel)
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.Line,
        BorderSizePixel = 0
    }, self.topBar)
    local searchWidth = self.IsMobile and 110 or 160
    local searchContainer = create("Frame", {
        Size = UDim2.new(0, searchWidth, 0, 28),
        Position = UDim2.new(1, -18, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Theme.HoverFill,
        BackgroundTransparency = 0.96,
        BorderSizePixel = 0,
        ClipsDescendants = true
    }, self.topBar)
    addCorner(searchContainer, 4)
    create("ImageLabel", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0, 8, 0.5, -7),
        BackgroundTransparency = 1,
        Image = icon("search"),
        ImageColor3 = Theme.TextSecondary
    }, searchContainer)
    self.searchBox = create("TextBox", {
        Size = UDim2.new(1, -32, 1, 0),
        Position = UDim2.new(0, 28, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Search...",
        PlaceholderColor3 = Theme.TextSecondary,
        TextColor3 = Theme.TextPrimary,
        Font = FONT,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ClipsDescendants = true
    }, searchContainer)
    local textContainer = create("Frame", {
        Size = UDim2.new(1, -(searchWidth + 18 + 24), 1, 0),
        Position = UDim2.new(0, 18, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, self.topBar)
    self.titleLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 22),
        Position = UDim2.new(0, 0, 0, 10),
        BackgroundTransparency = 1,
        TextColor3 = Theme.TitleText,
        TextSize = 18,
        Font = FONT_BOLD,
        Text = self.Title,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    }, textContainer)
    self.subtitleLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 0, 29),
        BackgroundTransparency = 1,
        TextColor3 = Theme.TextSecondary,
        TextSize = 11,
        Font = FONT,
        Text = self.SubTitle,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    }, textContainer)
    table.insert(self.connections, self.searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        self:_scheduleFilter()
    end))
end

function Library:_acquireGroup(index)
    local group = self.searchGroups[index]
    if group then
        return group
    end
    local frame = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.HoverFill,
        BackgroundTransparency = 0.98,
        BorderSizePixel = 0
    })
    addCorner(frame, 6)
    addStroke(frame, Theme.Line, 1)
    addPadding(frame, 10, 10, 10, 10)
    addList(frame, Metrics.ElementGap)
    local header = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        LayoutOrder = 0,
        Font = FONT_BOLD,
        TextSize = 11,
        Text = "",
        TextColor3 = Theme.TextHeader,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    }, frame)
    group = { frame = frame, header = header }
    self.searchGroups[index] = group
    return group
end

function Library:_restoreSearch()
    local moved = self.searchMoved
    for index = #moved, 1, -1 do
        local item = moved[index]
        if item.frame.Parent and item.home.Parent then
            item.frame.Parent = item.home
        end
        moved[index] = nil
    end
    for _, group in ipairs(self.searchGroups) do
        group.frame.Parent = nil
    end
    if self.searchPage then
        self.searchPage.Visible = false
    end
    if self.searchEmpty then
        self.searchEmpty.Visible = false
    end
end

function Library:_applyFilter(query)
    self:_restoreSearch()
    if query == "" then
        for _, tab in ipairs(self.tabs) do
            tab.page.Visible = tab == self.selectedTab
        end
        return
    end
    for _, tab in ipairs(self.tabs) do
        tab.page.Visible = false
    end
    local tabIndexes = {}
    for index, tab in ipairs(self.tabs) do
        tabIndexes[tab] = index
    end
    local fallbackInfo = { title = "Results", order = 0 }
    local titleMatches = {}
    local buckets = {}
    local ordered = {}
    for _, entry in ipairs(Elements._searchRegistry) do
        local frame = entry.frame
        if frame.Parent then
            local sectionFrame = entry.section
            if not (sectionFrame and Elements._sections[sectionFrame]) then
                sectionFrame = frame.Parent
                while sectionFrame and not Elements._sections[sectionFrame] do
                    sectionFrame = sectionFrame.Parent
                end
            end
            local info = sectionFrame and Elements._sections[sectionFrame] or fallbackInfo
            local titleMatch = titleMatches[info]
            if titleMatch == nil then
                titleMatch = string.find(tostring(info.title):lower(), query, 1, true) ~= nil
                titleMatches[info] = titleMatch
            end
            if titleMatch or string.find(entry.label, query, 1, true) then
                local bucket = buckets[info]
                if not bucket then
                    local tabRank = info.tab and (tabIndexes[info.tab] or 0) or 1000000
                    bucket = { info = info, items = {}, rank = tabRank * 10000 + info.order }
                    buckets[info] = bucket
                    ordered[#ordered + 1] = bucket
                end
                bucket.items[#bucket.items + 1] = entry
            end
        end
    end
    table.sort(ordered, function(a, b)
        return a.rank < b.rank
    end)
    if #ordered == 0 then
        self.searchEmpty.Visible = true
        self.searchPage.CanvasPosition = Vector2.zero
        self.searchPage.Visible = true
        return
    end
    for index, bucket in ipairs(ordered) do
        local group = self:_acquireGroup(index)
        local info = bucket.info
        local tabPrefix = info.tab and (info.tab.name .. " / ") or ""
        group.header.Text = (tabPrefix .. tostring(info.title)):upper()
        group.frame.LayoutOrder = index
        group.frame.Parent = self.searchPage
        for _, entry in ipairs(bucket.items) do
            local frame = entry.frame
            self.searchMoved[#self.searchMoved + 1] = { frame = frame, home = frame.Parent }
            frame.Parent = group.frame
        end
    end
    self.searchPage.CanvasPosition = Vector2.zero
    self.searchPage.Visible = true
end

function Library:_filterElements(rawQuery)
    local query = tostring(rawQuery):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if query == self.appliedQuery then
        return
    end
    self.appliedQuery = query
    local ok, err = pcall(self._applyFilter, self, query)
    if not ok then
        self.appliedQuery = ""
        pcall(self._restoreSearch, self)
        for _, tab in ipairs(self.tabs) do
            tab.page.Visible = tab == self.selectedTab
        end
        Report("Error", "Ecohub | Search", Bypass:Resolve(err), "search", 6)
    end
end

function Library:_scheduleFilter()
    self.searchToken = self.searchToken + 1
    local token = self.searchToken
    task.delay(0.12, function()
        if self.searchToken == token and self.screenGui and self.searchBox then
            self:_filterElements(self.searchBox.Text)
        end
    end)
end

function Library:ClearSearch()
    if self.searchBox and self.searchBox.Text ~= "" then
        self.searchToken = self.searchToken + 1
        self.searchBox.Text = ""
        self:_filterElements("")
    end
end

function Library:_createContent()
    local tabWidth = self.IsMobile and Metrics.TabWidthMobile or Metrics.TabWidthPC
    self.contentFrame = create("Frame", {
        Size = UDim2.new(1, 0, 1, -Metrics.TopBarHeight),
        Position = UDim2.new(0, 0, 0, Metrics.TopBarHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 1,
        ClipsDescendants = true
    }, self.mainPanel)
    self.tabBar = create("ScrollingFrame", {
        Size = UDim2.new(0, tabWidth, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        ClipsDescendants = true,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0)
    }, self.contentFrame)
    self.tabDivider = create("Frame", {
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(0, tabWidth - 1, 0, 0),
        BackgroundColor3 = Theme.Line,
        BorderSizePixel = 0,
        ZIndex = 2
    }, self.contentFrame)
    addList(self.tabBar, 2)
    addPadding(self.tabBar, 8, 8, 6, 6)
    self.tabContent = create("Frame", {
        Size = UDim2.new(1, -tabWidth, 1, 0),
        Position = UDim2.new(0, tabWidth, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true
    }, self.contentFrame)
    self.searchPage = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ClipsDescendants = true,
        Visible = false
    }, self.tabContent)
    addPadding(self.searchPage, Metrics.PagePadding, Metrics.PagePadding, Metrics.PagePadding, Metrics.PagePadding)
    addList(self.searchPage, Metrics.SectionGap)
    self.searchEmpty = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        LayoutOrder = 0,
        Font = FONT,
        TextSize = 13,
        Text = "No results found",
        TextColor3 = Theme.TextSecondary,
        Visible = false
    }, self.searchPage)
end

function Library:_createToggleButton()
    local toggleGui = create("ScreenGui", {
        Name = Bypass:RandomName(),
        ResetOnSpawn = false,
        DisplayOrder = 1000
    })
    Bypass:PlaceGui(toggleGui)
    Bypass:HideObject(toggleGui)
    self.toggleGui = toggleGui
    local toggleButton = create("TextButton", {
        Size = UDim2.new(0, 48, 0, 48),
        Position = UDim2.new(0, 20, 0.5, -24),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true
    }, toggleGui)
    addCorner(toggleButton, 10)
    local stroke = addStroke(toggleButton, Theme.Line, 1.5)
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    local texture = create("ImageLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = "rbxassetid://77526194033506",
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 1
    }, toggleButton)
    addCorner(texture, 10)
    local isActualDrag = false
    local dragStart = Vector3.zero
    local startPosition = toggleButton.Position
    local moveConnection = nil
    local endConnection = nil
    local function stopTracking()
        if moveConnection then
            moveConnection:Disconnect()
            moveConnection = nil
        end
        if endConnection then
            endConnection:Disconnect()
            endConnection = nil
        end
    end
    self.toggleCleanup = stopTracking
    table.insert(self.connections, toggleButton.InputBegan:Connect(function(input)
        if not isPointerInput(input) then
            return
        end
        isActualDrag = false
        dragStart = input.Position
        startPosition = toggleButton.Position
        stopTracking()
        moveConnection = UserInputService.InputChanged:Connect(function(moveInput)
            if not isMoveInput(moveInput) then
                return
            end
            local delta = moveInput.Position - dragStart
            if delta.Magnitude > 7 then
                isActualDrag = true
            end
            if isActualDrag then
                toggleButton.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
            end
        end)
        endConnection = UserInputService.InputEnded:Connect(function(endInput)
            if not isPointerInput(endInput) then
                return
            end
            stopTracking()
            if not isActualDrag then
                self:Toggle()
            end
            isActualDrag = false
        end)
    end))
end

function Library:_setupDrag()
    local dragging = false
    local dragStart = Vector3.zero
    local startPosition = self.mainPanel.Position
    table.insert(self.connections, self.topBar.InputBegan:Connect(function(input)
        if not isPointerInput(input) then
            return
        end
        dragging = true
        dragStart = input.Position
        startPosition = self.mainPanel.Position
        if self.dragConnection then
            self.dragConnection:Disconnect()
        end
        self.dragConnection = UserInputService.InputChanged:Connect(function(moveInput)
            if not dragging or not isMoveInput(moveInput) then
                return
            end
            local delta = moveInput.Position - dragStart
            self.mainPanel.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        end)
    end))
    table.insert(self.connections, UserInputService.InputEnded:Connect(function(input)
        if not dragging or not isPointerInput(input) then
            return
        end
        dragging = false
        if self.dragConnection then
            self.dragConnection:Disconnect()
            self.dragConnection = nil
        end
    end))
end

function Library:Destroy()
    if self.loadedFeatures then
        pcall(self._unloadAll, self)
    end
    pcall(self._restoreSearch, self)
    for _, connection in ipairs(self.connections) do
        pcall(connection.Disconnect, connection)
    end
    table.clear(self.connections)
    if self.dragConnection then
        pcall(self.dragConnection.Disconnect, self.dragConnection)
        self.dragConnection = nil
    end
    if self.toggleCleanup then
        pcall(self.toggleCleanup)
        self.toggleCleanup = nil
    end
    table.clear(Elements._searchRegistry)
    table.clear(Elements._searchSet)
    if self.screenGui then
        self.screenGui:Destroy()
        self.screenGui = nil
    end
    if self.toggleGui then
        self.toggleGui:Destroy()
        self.toggleGui = nil
    end
    if env.__EcohubWindow == self then
        env.__EcohubWindow = nil
    end
    if env.Windows == self then
        env.Windows = nil
    end
    if env.Window == self then
        env.Window = nil
    end
end

function Library:SelectTab(target)
    local tab = target
    if type(target) == "string" then
        tab = nil
        for _, candidate in ipairs(self.tabs) do
            if candidate.name == target then
                tab = candidate
                break
            end
        end
    elseif type(target) == "number" then
        tab = self.tabs[target]
    end
    if type(tab) ~= "table" or tab.window ~= self then
        return false
    end
    self:ClearSearch()
    if self.selectedTab == tab then
        return true
    end
    local previous = self.selectedTab
    self.selectedTab = tab
    if previous then
        previous.updateVisuals(false)
    end
    tab.updateVisuals(true)
    return true
end

function Library:CreateTab(options)
    local window = self
    local isTable = type(options) == "table"
    local sectionName = isTable and options.section or nil
    local tabName = isTable and (options.tab or options.name) or options
    local iconName = isTable and options.icon or nil
    if sectionName and not self.sectionIndexes[sectionName] then
        self.sectionCount = self.sectionCount + 1
        self.sectionIndexes[sectionName] = self.sectionCount
        local headerContainer = create("Frame", {
            Size = UDim2.new(1, -12, 0, 26),
            BackgroundTransparency = 1,
            LayoutOrder = self.sectionCount * 1000
        }, self.tabBar)
        create("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(0, 8, 0, 4),
            BackgroundTransparency = 1,
            Text = sectionName,
            Font = FONT,
            TextSize = 12,
            TextColor3 = Theme.TextHeader,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd
        }, headerContainer)
        self.sections[sectionName] = headerContainer
    end
    self.tabCounter = self.tabCounter + 1
    local orderBase = sectionName and self.sectionIndexes[sectionName] or self.sectionCount
    local tabData = {
        name = tostring(tabName),
        section = sectionName,
        sectionCount = 0,
        selected = false,
        window = window
    }
    local button = create("TextButton", {
        Size = UDim2.new(1, -12, 0, 30),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        BorderSizePixel = 0,
        LayoutOrder = orderBase * 1000 + self.tabCounter
    }, self.tabBar)
    local highlight = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.HoverFill,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    }, button)
    addCorner(highlight, 4)
    local indicatorBar = create("Frame", {
        Size = UDim2.new(0, 2, 0, 0),
        Position = UDim2.new(0, 2, 0.5, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        BackgroundTransparency = 1
    }, button)
    local iconLabel = nil
    if iconName and ICONS.assets then
        local foundIcon = ICONS.assets["lucide-" .. iconName]
        if foundIcon then
            iconLabel = create("ImageLabel", {
                Size = UDim2.new(0, 14, 0, 14),
                Position = UDim2.new(0, 14, 0.5, -7),
                BackgroundTransparency = 1,
                Image = foundIcon,
                ImageColor3 = Theme.TextSecondary
            }, button)
        end
    end
    local textOffset = iconLabel and 34 or 14
    local tabLabel = create("TextLabel", {
        Size = UDim2.new(1, -textOffset, 1, 0),
        Position = UDim2.new(0, textOffset, 0, 0),
        BackgroundTransparency = 1,
        Text = tabData.name,
        Font = FONT,
        TextSize = 13,
        TextColor3 = Theme.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    }, button)
    local page = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ClipsDescendants = true,
        Visible = false
    }, self.tabContent)
    local pagePadding = addPadding(page, Metrics.PagePadding, Metrics.PagePadding, Metrics.PagePadding, Metrics.PagePadding)
    addList(page, Metrics.SectionGap)

    local function relayout()
        local padding = UDim.new(0, window.compact and Metrics.PagePaddingShort or Metrics.PagePadding)
        pagePadding.PaddingTop = padding
        pagePadding.PaddingLeft = padding
        pagePadding.PaddingRight = padding
        pagePadding.PaddingBottom = padding
    end

    tabData.relayout = relayout
    tabData.button = button
    tabData.page = page
    relayout()

    local function updateTabVisuals(isSelected, instant)
        tabData.selected = isSelected
        local searchActive = window.searchBox and window.searchBox.Text ~= ""
        local textColor = isSelected and Theme.TextPrimary or Theme.TextSecondary
        animate(tabLabel, Tweens.Tab, { TextColor3 = textColor }, instant)
        tabLabel.Font = isSelected and FONT_BOLD or FONT
        if iconLabel then
            animate(iconLabel, Tweens.Tab, { ImageColor3 = textColor }, instant)
        end
        animate(highlight, Tweens.Tab, { BackgroundTransparency = isSelected and 0.94 or 1 }, instant)
        animate(indicatorBar, Tweens.Tab, {
            Size = isSelected and UDim2.new(0, 2, 0, 14) or UDim2.new(0, 2, 0, 0),
            Position = isSelected and UDim2.new(0, 2, 0.5, -7) or UDim2.new(0, 2, 0.5, 0),
            BackgroundTransparency = isSelected and 0 or 1
        }, instant)
        if isSelected then
            relayout()
            if not searchActive then
                page.Visible = true
                if instant then
                    cancelTween(page)
                    page.Position = UDim2.new()
                else
                    page.Position = UDim2.fromOffset(0, Metrics.PageSlide)
                    tween(page, Tweens.Page, { Position = UDim2.new() })
                end
            end
        else
            cancelTween(page)
            page.Position = UDim2.new()
            page.Visible = false
        end
    end

    tabData.updateVisuals = updateTabVisuals

    table.insert(self.connections, button.MouseButton1Click:Connect(function()
        window:SelectTab(tabData)
    end))
    table.insert(self.connections, button.MouseEnter:Connect(function()
        if not tabData.selected and not window.IsMobile then
            tween(highlight, Tweens.Hover, { BackgroundTransparency = 0.97 })
        end
    end))
    table.insert(self.connections, button.MouseLeave:Connect(function()
        if not tabData.selected then
            tween(highlight, Tweens.Hover, { BackgroundTransparency = 1 })
        end
    end))

    table.insert(self.tabs, tabData)
    if #self.tabs == 1 then
        self.selectedTab = tabData
        updateTabVisuals(true, true)
    end

    function tabData:CreateSection(sectionTitle)
        tabData.sectionCount = tabData.sectionCount + 1
        local sectionFrame = create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.HoverFill,
            BackgroundTransparency = 0.98,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            LayoutOrder = tabData.sectionCount
        }, page)
        addCorner(sectionFrame, 6)
        addStroke(sectionFrame, Theme.Line, 1)
        addPadding(sectionFrame, 10, 10, 10, 10)
        addList(sectionFrame, Metrics.ElementGap)
        local headerFrame = create("Frame", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = 0
        }, sectionFrame)
        local headerAccent = create("Frame", {
            Size = UDim2.new(0, 3, 0, 12),
            Position = UDim2.new(0, 0, 0.5, -6),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 0.35,
            BorderSizePixel = 0
        }, headerFrame)
        addCorner(headerAccent, 8)
        local titleLabel = create("TextLabel", {
            Size = UDim2.new(1, -10, 1, 0),
            Position = UDim2.new(0, 10, 0, 0),
            BackgroundTransparency = 1,
            Text = tostring(sectionTitle):upper(),
            Font = FONT_BOLD,
            TextSize = 11,
            TextColor3 = Theme.TextHeader,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd
        }, headerFrame)
        local sectionInfo = { tab = tabData, title = tostring(sectionTitle), order = tabData.sectionCount }
        Elements._sections[sectionFrame] = sectionInfo
        local sectionData = { frame = sectionFrame, window = window, elementCount = 0 }

        function sectionData:SetTitle(text)
            titleLabel.Text = tostring(text):upper()
            sectionInfo.title = tostring(text)
        end

        local function wrapElement(constructorName, opts)
            local constructor = Elements.List[constructorName] or Library:_loadMissingElement(constructorName)
            if not constructor then
                Report("Error", "Ecohub | Element", constructorName .. " is not registered", "element:" .. constructorName, 5)
                return nil
            end
            sectionData.elementCount = sectionData.elementCount + 1
            local holder = create("Frame", {
                Name = constructorName,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ClipsDescendants = false,
                LayoutOrder = sectionData.elementCount + 1
            }, sectionFrame)
            create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, holder)
            local holderSection = setmetatable({ frame = holder, window = window }, { __index = sectionData })
            local label = (type(opts) == "table" and (opts.name or opts.title or opts.text or opts.label)) or (type(opts) == "string" and opts) or ""
            label = label ~= "" and tostring(label) or ""
            local ok, result = pcall(constructor, holderSection, protectOptions(opts, label ~= "" and label or constructorName))
            if not ok then
                holder:Destroy()
                Report("Error", "Ecohub | " .. constructorName, Bypass:Resolve(result), "element:" .. constructorName .. ":" .. label, 6)
                return nil
            end
            if label ~= "" then
                Elements.RegisterSearchEntry(label, holder, sectionFrame)
            end
            return result or holder
        end

        for methodName, constructorName in pairs(ELEMENT_METHODS) do
            sectionData[methodName] = function(_, opts)
                return wrapElement(constructorName, opts)
            end
        end

        function sectionData:CreateElement(name, opts)
            return wrapElement(name, opts)
        end

        setmetatable(sectionData, {
            __index = function(_, key)
                if type(key) ~= "string" then
                    return nil
                end
                local name = key:match("^Create(%w+)$")
                if name and Elements.List[name] then
                    return function(_, opts)
                        return wrapElement(name, opts)
                    end
                end
                return nil
            end
        })

        return sectionData
    end

    return tabData
end

return Library