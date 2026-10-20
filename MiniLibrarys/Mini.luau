-- // Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() and Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- // Environment
local getEnv = function()
    return getgenv and getgenv() or _G
end

local isMobile = function()
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- // Theme
local Theme = {
    Panel = Color3.fromRGB(28, 28, 28),
    Card = Color3.fromRGB(28, 28, 28),
    TextPrimary = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(105, 105, 115),
    Line = Color3.fromRGB(42, 42, 42),
    LineActive = Color3.fromRGB(75, 75, 82)
}

-- // Metrics
local Metrics = {
    DrawerWidth = 330,
    HeaderHeight = 60,
    TabBarHeight = 64,
    TabSize = 48,
    TabExpanded = 160,
    TabGap = 8,
    TabBarPadding = 10,
    ToggleSize = 48,
    DragThreshold = 7,
    PagePadding = 12,
    ElementGap = 6
}

-- // Tweens
local Tweens = {
    Drawer = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    Card = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    Hover = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Scroll = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    Dropdown = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
}

-- // Helpers
local report = function(kind, title, text)
    if text == nil then
        text = title
    end
    print(tostring(text))
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
    return create("UIStroke", {
        Color = color,
        Thickness = thickness,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    }, parent)
end

local getViewport = function()
    local camera = workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end
    return Vector2.new(1280, 720)
end

local offsetPosition = function(position, delta)
    return UDim2.new(
        position.X.Scale,
        position.X.Offset + delta.X,
        position.Y.Scale,
        position.Y.Offset + delta.Y
    )
end

local isPointerInput = function(input)
    local inputType = input.UserInputType
    return inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch
end

local isMoveInput = function(input)
    local inputType = input.UserInputType
    return inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Touch
end

local trim = function(text)
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

-- // Extensions
local ScriptExtensions = { ".lua", ".luau" }

local getExtension = function(path)
    local lowered = tostring(path):lower()
    for _, extension in ipairs(ScriptExtensions) do
        if #lowered >= #extension and lowered:sub(-#extension) == extension then
            return extension
        end
    end
    return nil
end

local hasScriptExtension = function(path)
    return getExtension(path) ~= nil
end

local extensionRank = function(path)
    local found = getExtension(path)
    for index, extension in ipairs(ScriptExtensions) do
        if extension == found then
            return index
        end
    end
    return math.huge
end

local stripExtension = function(path)
    local extension = getExtension(path)
    if extension then
        return path:sub(1, #path - #extension)
    end
    return path
end

-- // Path Helpers
local encodePath = function(path)
    local encoded = path:gsub("[^%w%-_%.~/]", function(character)
        return string.format("%%%02X", character:byte())
    end)
    return encoded
end

local cacheBust = function(url, salt)
    local separator = url:find("?", 1, true) and "&" or "?"
    return url .. separator .. "cb=" .. os.time() .. "_" .. salt
end

local upperText = function(text)
    text = tostring(text):upper()
    return (text:gsub("\195([\160-\190])", function(byte)
        if byte == "\183" then
            return nil
        end
        return "\195" .. string.char(byte:byte() - 32)
    end))
end

-- // Tween
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

-- // Gui Placement
local getHui = function()
    if not gethui then
        return nil
    end
    local ok, result = pcall(gethui)
    if ok then
        return result
    end
    return nil
end

local cleanupGuis = function(parent)
    if not parent then
        return
    end
    local ok, children = pcall(parent.GetChildren, parent)
    if not ok then
        return
    end
    for _, child in ipairs(children) do
        if child:IsA("ScreenGui") and child.Name == "DrawerMiniGui" then
            pcall(child.Destroy, child)
        end
    end
end

local placeGui = function(gui)
    local hui = getHui()
    if not hui then
        if syn and syn.protect_gui then
            pcall(syn.protect_gui, gui)
        end
        local ok = pcall(function()
            gui.Parent = CoreGui
        end)
        if ok and gui.Parent then
            return
        end
    end
    gui.Parent = hui or PlayerGui
end

-- // Icons
local loadRemote = function(url)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if ok and type(result) == "table" then
        return result
    end
    return nil
end

local loadIcons = function()
    local base = "https://raw.githubusercontent.com/pvpgalinhamonzonrebasexk/monzonrebasexk/refs/heads/main/Assets/Icons"
    for _, extension in ipairs(ScriptExtensions) do
        local data = loadRemote(base .. extension)
        if data then
            return data.assets or data
        end
    end
    return {}
end

local IconTable = loadIcons()

local resolveIcon = function(key, fallback)
    if type(key) ~= "string" or key == "" then
        return fallback or ""
    end
    if key:match("^rbxassetid://") or key:match("^http") then
        return key
    end
    return IconTable[key] or IconTable["lucide-" .. key] or fallback or ""
end

-- // Loader
local Loader = {
    Chunks = {}
}

function Loader:RandomName()
    local nameChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
    local characters = {}
    for index = 1, math.random(8, 14) do
        local position = math.random(1, #nameChars)
        characters[index] = nameChars:sub(position, position)
    end
    return table.concat(characters)
end

function Loader:Validate(body)
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

function Loader:Compile(source, displayName)
    local chunkName = Loader:RandomName()
    local fn, compileError = loadstring(source, "=" .. chunkName)
    Loader.Chunks[chunkName] = displayName
    if not fn and type(compileError) == "string" then
        local target = tonumber(compileError:match("^[%w_%-]+:(%d+):"))
        if target then
            local current = 0
            for line in (source .. "\n"):gmatch("([^\n]*)\n") do
                current = current + 1
                if current == target then
                    compileError = compileError .. " >> " .. trim(line)
                    break
                end
            end
        end
    end
    return fn, compileError
end

function Loader:Resolve(message)
    local text = tostring(message)
    local chunkName = text:match("^([%w_%-]+):%d+:")
    local displayName = chunkName and Loader.Chunks[chunkName]
    if displayName then
        return displayName .. text:sub(#chunkName + 1)
    end
    return text
end

-- // Safe Call
local safeCall = function(callback, ...)
    if type(callback) ~= "function" then
        return nil
    end
    local ok, result = pcall(callback, ...)
    if not ok then
        report("Error", "Element", Loader:Resolve(result))
        return nil
    end
    return result
end

-- // Library
local Library = {}
Library.__index = Library

Library.Theme = Theme
Library.Metrics = Metrics
Library.Tweens = Tweens
Library.Tween = tween
Library.CancelTween = cancelTween
Library.Loader = Loader
Library.GetIcon = resolveIcon
Library.Report = report
Library.Trim = trim
Library.UpperText = upperText
Library.SafeCall = safeCall
Library.GetViewport = getViewport
Library.GetEnv = getEnv
Library.IsMobile = isMobile()
Library.MiniFeatures = {}
Library.Extensions = ScriptExtensions
Library.GetExtension = getExtension
Library.CurrentLanguage = "en"
Library.LanguageListeners = {}

-- // MiniFeatures Config
local treeStore = getEnv().__MiniFeaturesTrees
if type(treeStore) ~= "table" then
    treeStore = {}
    getEnv().__MiniFeaturesTrees = treeStore
end

local missCache = {}

local miniConfig = {
    TreeTtl = 60,
    TreeRetry = 30,
    MissTtl = 10,
    Retries = 3,
    RetryDelay = 0.3,
    MaxParallel = isMobile() and 3 or 6,
    Timeout = 30,
    StartTimeout = 2
}

Library.MiniFeatureConfig = miniConfig

local miniSource = nil

-- // MiniFeatures Source
local newSource = function(url)
    local pattern = "^https?://github%.com/([^/]+)/([^/]+)/tree/([^/]+)/?(.*)$"
    local owner, repoName, branch, root = url:match(pattern)
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

function Library:SetMiniFeaturesSource(url)
    local source = newSource(url)
    if not source then
        return false
    end
    miniSource = source
    Library.MiniFeaturesSource = url
    Library.MiniFeaturesUrl = source.RawUrl
    return true
end

Library:SetMiniFeaturesSource("https://github.com/pvpgalinhamonzonrebasexk/monzonrebasexk/tree/main/MiniFeatures")

local cleanMiniFeatureName = function(name)
    name = name:gsub("\\", "/")
    name = trim(name)
    name = name:gsub("^/+", "")
    name = name:gsub("/+$", "")
    name = stripExtension(name)
    local root = miniSource.Root
    if root == "" then
        return name
    end
    local prefix = root:lower() .. "/"
    if name:lower():sub(1, #prefix) == prefix then
        name = name:sub(#prefix + 1)
    end
    return name
end

-- // MiniFeatures Fetch
local requestOnce = function(url, attempt)
    local target = cacheBust(url, attempt)
    local httpRequest = request or http_request or (syn and syn.request)
    return pcall(function()
        if httpRequest then
            local response = httpRequest({
                Url = target,
                Method = "GET",
                Headers = {
                    ["User-Agent"] = "Mozilla/5.0",
                    ["Cache-Control"] = "no-cache"
                }
            })
            if type(response) == "table" then
                local status = response.StatusCode
                if not status then
                    status = response.Success and 200 or 0
                end
                return response.Body, status
            end
            return nil, 0
        end
        return game:HttpGet(target), 200
    end)
end

local classifyFailure = function(ok, body, status)
    if ok then
        if status == 404 then
            return "missing", "not found"
        end
        if status == 403 or status == 429 then
            return "limited", "rate limited"
        end
        if type(status) == "number" and status >= 400 and status < 500 and status ~= 408 then
            return "fatal", "HTTP " .. status
        end
        if status == 0 then
            return "retry", "no response"
        end
        return "retry", "HTTP " .. tostring(status)
    end
    local message = tostring(body)
    if message:find("404", 1, true) then
        return "missing", "not found"
    end
    if message:find("403", 1, true) or message:find("429", 1, true) then
        return "limited", "rate limited"
    end
    return "retry", message
end

local fetchSource = function(url)
    local missTime = missCache[url]
    if missTime and os.clock() - missTime < miniConfig.MissTtl then
        return nil, "not found"
    end
    local reason = "request failed"
    for attempt = 1, miniConfig.Retries do
        local ok, body, status = requestOnce(url, attempt)
        if ok and status == 200 then
            local valid, invalid = Loader:Validate(body)
            if valid then
                return body
            end
            if invalid == "not found" then
                missCache[url] = os.clock()
            end
            return nil, invalid
        end
        local kind, detail = classifyFailure(ok, body, status)
        if kind == "missing" then
            missCache[url] = os.clock()
            return nil, detail
        end
        if kind == "limited" or kind == "fatal" then
            return nil, detail
        end
        reason = detail
        if attempt < miniConfig.Retries then
            task.wait(miniConfig.RetryDelay * attempt)
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
    local workers = math.min(miniConfig.MaxParallel, total)
    local runWorker = function()
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
    end
    for _ = 1, workers do
        task.spawn(runWorker)
    end
    local startTime = os.clock()
    while finished < workers and os.clock() - startTime < miniConfig.Timeout do
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

-- // MiniFeatures Index
local getStore = function(source)
    local store = treeStore[source.TreeApi]
    if not store then
        store = {
            entries = nil,
            time = 0,
            failedAt = nil,
            stamp = 0
        }
        treeStore[source.TreeApi] = store
    end
    return store
end

local parseTree = function(body)
    local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
    if not ok or type(data) ~= "table" or type(data.tree) ~= "table" then
        return nil
    end
    local entries = {}
    for _, node in ipairs(data.tree) do
        local path = node.path
        local isScript = type(path) == "string" and hasScriptExtension(path)
        if node.type == "blob" and isScript then
            entries[#entries + 1] = path
        end
    end
    return entries
end

local refreshTree = function(source, force)
    local now = os.time()
    local store = getStore(source)
    local usable = store.entries and store or nil
    if not force then
        if store.entries and now - store.time < miniConfig.TreeTtl then
            return store
        end
        if store.failedAt and now - store.failedAt < miniConfig.TreeRetry then
            return usable
        end
    end
    local body = fetchSource(source.TreeApi)
    local entries = body and parseTree(body) or nil
    if not entries then
        store.failedAt = now
        return usable
    end
    store.entries = entries
    store.time = now
    store.failedAt = nil
    store.stamp = store.stamp + 1
    return store
end

local buildEntry = function(relative)
    local key = stripExtension(relative)
    local lowerKey = key:lower()
    return {
        path = relative,
        key = key,
        lkey = lowerKey,
        lpath = relative:lower(),
        base = lowerKey:match("([^/]+)$")
    }
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
        local inScope = path:sub(1, prefixLength) == prefix
        local relative = path:sub(prefixLength + 1)
        if inScope and relative ~= "" then
            local entry = buildEntry(relative)
            local existing = byKey[entry.lkey]
            if not existing then
                byKey[entry.lkey] = entry
                entries[#entries + 1] = entry
            elseif extensionRank(relative) < extensionRank(existing.path) then
                local position = table.find(entries, existing)
                if position then
                    entries[position] = entry
                end
                byKey[entry.lkey] = entry
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

-- // MiniFeatures Match
local matchMiniFeatureFiles = function(entries, name)
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

local miniFeatureCandidates = function(name)
    local list = {}
    local seen = {}
    for _, variant in ipairs({ name, name:upper(), name:lower() }) do
        local last = variant:match("([^/]+)$") or variant
        local paths = {}
        for _, extension in ipairs(ScriptExtensions) do
            paths[#paths + 1] = variant .. extension
        end
        for _, extension in ipairs(ScriptExtensions) do
            paths[#paths + 1] = variant .. "/" .. last .. extension
        end
        for _, extension in ipairs(ScriptExtensions) do
            paths[#paths + 1] = variant .. "/init" .. extension
        end
        for _, path in ipairs(paths) do
            if not seen[path] then
                seen[path] = true
                list[#list + 1] = path
            end
        end
    end
    return list
end

-- // MiniFeatures Targets
local toRawUrl = function(item)
    local rawUrl = item:gsub(
        "^https?://github%.com/([^/]+)/([^/]+)/blob/",
        "https://raw.githubusercontent.com/%1/%2/"
    )
    rawUrl = rawUrl:gsub(
        "^https?://github%.com/([^/]+)/([^/]+)/raw/",
        "https://raw.githubusercontent.com/%1/%2/"
    )
    return rawUrl
end

local buildUrlTargets = function(item)
    local rawUrl = toRawUrl(item)
    local base = rawUrl:gsub("[?#].*$", "")
    local hasExtension = hasScriptExtension(base)
    local short = stripExtension(base:match("([^/]+)/?$") or base)
    if hasExtension or rawUrl ~= base then
        return {
            { key = short, urls = { rawUrl } }
        }
    end
    local urls = {}
    for _, extension in ipairs(ScriptExtensions) do
        urls[#urls + 1] = rawUrl .. extension
    end
    urls[#urls + 1] = rawUrl
    return {
        { key = short, urls = urls, fallback = true }
    }
end

local buildTreeTargets = function(item)
    local source = newSource(item)
    local entries = source and scopedEntries(source, false)
    if not entries or #entries == 0 then
        return nil, "Folder not found or GitHub index unavailable: " .. item
    end
    local targets = {}
    for _, entry in ipairs(entries) do
        targets[#targets + 1] = {
            key = entry.key,
            urls = { source.RawUrl .. encodePath(entry.path) }
        }
    end
    return targets, nil, item
end

local buildIndexTargets = function(entries, name, isAll)
    local matches, kind = matchMiniFeatureFiles(entries, name)
    if #matches == 0 then
        entries = scopedEntries(miniSource, true) or entries
        matches, kind = matchMiniFeatureFiles(entries, name)
    end
    if #matches > 1 and kind == "name" then
        return nil, "Ambiguous name: " .. name .. ". Use folder/file, e.g. " .. matches[1].key
    end
    if #matches == 0 then
        if isAll then
            return nil, "No MiniFeatures found in the folder"
        end
        return nil, "MiniFeature not found: " .. name
    end
    local targets = {}
    for _, entry in ipairs(matches) do
        targets[#targets + 1] = {
            key = entry.key,
            urls = { miniSource.RawUrl .. encodePath(entry.path) }
        }
    end
    return targets, nil, name
end

local buildFallbackTargets = function(name)
    local urls = {}
    for _, candidate in ipairs(miniFeatureCandidates(name)) do
        urls[#urls + 1] = miniSource.RawUrl .. encodePath(candidate)
    end
    return {
        { key = name, urls = urls, fallback = true }
    }
end

local buildTargets = function(item)
    if item:match("^https?://") then
        if item:match("^https?://github%.com/[^/]+/[^/]+/tree/") then
            return buildTreeTargets(item)
        end
        return buildUrlTargets(item)
    end
    local name = cleanMiniFeatureName(item)
    if name == "" then
        return nil, "LoadMiniFeature needs a name or link"
    end
    local isAll = name == "*" or name:lower() == "all"
    local entries = scopedEntries(miniSource, false)
    if entries then
        return buildIndexTargets(entries, name, isAll)
    end
    if isAll then
        return nil, "GitHub index unavailable, cannot load all MiniFeatures"
    end
    report("Warning", "API", "GitHub index unavailable, using direct links")
    return buildFallbackTargets(name)
end

-- // MiniFeatures API
local isWindow = function(target)
    if target == Library or type(target) ~= "table" then
        return false
    end
    return type(target.tabs) == "table"
end

local requireWindow = function(target, method)
    if isWindow(target) then
        return true
    end
    report("Error", "API", "Use Window:" .. method .. "(...), not MiniLibrary:" .. method .. "(...)")
    return false
end

local resolveWindow = function(target)
    if isWindow(target) then
        return target
    end
    local current = getEnv().__MiniWindow
    if isWindow(current) then
        return current
    end
    return target
end

function Library:_resolveWindow()
    return resolveWindow(self)
end

function Library:RefreshMiniFeatures()
    return scopedEntries(miniSource, true) ~= nil
end

function Library:ListMiniFeatures()
    local entries = scopedEntries(miniSource, false)
    local list = {}
    if entries then
        for _, entry in ipairs(entries) do
            list[#list + 1] = entry.key
        end
    end
    return list
end

function Library:GetLoadedMiniFeatures()
    self = resolveWindow(self)
    local list = {}
    if type(self.loadedMiniFeatures) == "table" then
        for key in pairs(self.loadedMiniFeatures) do
            list[#list + 1] = key
        end
    end
    table.sort(list)
    return list
end

function Library:IsMiniFeatureLoaded(nameOrKey)
    self = resolveWindow(self)
    if type(self.loadedMiniFeatures) ~= "table" then
        return false
    end
    local lowered = cleanMiniFeatureName(tostring(nameOrKey)):lower()
    for key in pairs(self.loadedMiniFeatures) do
        local lowerKey = key:lower()
        local baseKey = lowerKey:match("([^/]+)$")
        if lowerKey == lowered or baseKey == lowered then
            return true
        end
    end
    return false
end

function Library:_exposeGlobals()
    local env = getEnv()
    local window = resolveWindow(self)
    env.MiniWindow = window
    env.Windows = window
    env.Window = window
    env.MiniLibrary = Library
    env.MiniElements = Library.MiniElements
    env.Elements = Library.MiniElements
end

-- // MiniFeatures Runner
function Library:_runMiniFeature(source, name)
    local fn, compileError = Loader:Compile(source, name)
    if not fn then
        report("Error", name, Loader:Resolve(compileError))
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
            report("Error", name, Loader:Resolve(runError))
        end
    end)
    local started = os.clock()
    while not run.done and os.clock() - started < miniConfig.StartTimeout do
        task.wait()
    end
    if run.done and not run.ok then
        return false
    end
    Library.MiniFeatures[name] = true
    return true
end

-- // MiniFeatures Unload
function Library:UnloadMiniFeature(nameOrKey)
    self = resolveWindow(self)
    if not requireWindow(self, "UnloadMiniFeature") then
        return false
    end
    local lowered = cleanMiniFeatureName(tostring(nameOrKey)):lower()
    local keys = {}
    for key in pairs(self.loadedMiniFeatures) do
        local lowerKey = key:lower()
        local baseKey = lowerKey:match("([^/]+)$")
        local isExact = lowerKey == lowered or baseKey == lowered
        local isFolder = lowerKey:sub(1, #lowered + 1) == lowered .. "/"
        if isExact or isFolder then
            keys[#keys + 1] = key
        end
    end
    if #keys == 0 then
        return false
    end
    for _, key in ipairs(keys) do
        local base = key:match("([^/]+)$")
        local env = getEnv()
        local unload = env[base .. "MiniUnload"] or env[base .. "Unload"]
        if type(unload) == "function" then
            local ok, unloadError = pcall(unload)
            if not ok then
                report("Error", key, Loader:Resolve(unloadError))
            end
        end
        self.loadedMiniFeatures[key] = nil
        Library.MiniFeatures[key] = nil
    end
    return true
end

function Library:_unloadAll()
    local keys = {}
    for key in pairs(self.loadedMiniFeatures) do
        keys[#keys + 1] = key
    end
    for _, key in ipairs(keys) do
        pcall(self.UnloadMiniFeature, self, key)
    end
end

function Library:UnloadAllMiniFeatures()
    self = resolveWindow(self)
    if not requireWindow(self, "UnloadAllMiniFeatures") then
        return false
    end
    self:_unloadAll()
    return true
end

-- // MiniFeatures Loader
function Library:_planItems(list, options, results)
    local plans = {}
    local urlSet = {}
    local urlList = {}
    for _, item in ipairs(list) do
        if type(item) ~= "string" or item == "" then
            report("Error", "API", "LoadMiniFeature needs a name or link")
        else
            local targets, err, group = buildTargets(item)
            if not targets then
                report("Error", "API", err)
                results[item] = false
            else
                plans[#plans + 1] = { item = item, targets = targets, group = group }
                for _, target in ipairs(targets) do
                    if options.Reload and self.loadedMiniFeatures[target.key] then
                        self:UnloadMiniFeature(target.key)
                    end
                    local url = target.urls[1]
                    if not self.loadedMiniFeatures[target.key] and not target.fallback and not urlSet[url] then
                        urlSet[url] = true
                        urlList[#urlList + 1] = url
                    end
                end
            end
        end
    end
    return plans, urlList
end

function Library:_resolveSource(target, bodies, reasons)
    local firstUrl = target.urls[1]
    if not target.fallback then
        return bodies[firstUrl], reasons[firstUrl]
    end
    local reason = nil
    for _, url in ipairs(target.urls) do
        local source, failure = fetchSource(url)
        if source then
            return source, nil
        end
        reason = failure
    end
    return nil, reason
end

function Library:_executePlans(plans, urlList, summary, results)
    local bodies, reasons = fetchAll(urlList)
    for _, plan in ipairs(plans) do
        local loaded = 0
        for _, target in ipairs(plan.targets) do
            if self.loadedMiniFeatures[target.key] then
                loaded = loaded + 1
            else
                local source, reason = self:_resolveSource(target, bodies, reasons)
                if source then
                    if self:_runMiniFeature(source, target.key) then
                        self.loadedMiniFeatures[target.key] = true
                        loaded = loaded + 1
                        summary.loaded = summary.loaded + 1
                    else
                        summary.failed = summary.failed + 1
                        summary.names[#summary.names + 1] = target.key
                    end
                    task.wait()
                else
                    local why = tostring(reason or "unknown")
                    if target.fallback then
                        why = "not found, index unavailable"
                    end
                    summary.failed = summary.failed + 1
                    summary.names[#summary.names + 1] = target.key .. " (" .. why .. ")"
                end
            end
        end
        if loaded > 0 and plan.group then
            Library.MiniFeatures[plan.group] = true
        end
        results[plan.item] = loaded > 0
    end
    table.clear(bodies)
end

function Library:_reportSummary(summary)
    if summary.failed == 0 then
        if summary.loaded > 0 then
            report("Success", "MiniFeatures", "Loaded " .. summary.loaded .. " MiniFeature(s)")
        end
        return
    end
    local kind = summary.loaded > 0 and "Warning" or "Error"
    report(
        kind,
        "MiniFeatures",
        "Loaded " .. summary.loaded .. ", failed " .. summary.failed .. ": " .. table.concat(summary.names, ", ")
    )
end

function Library:_loadItems(list, options)
    options = type(options) == "table" and options or {}
    local results = {}
    local plans, urlList = self:_planItems(list, options, results)
    if #plans == 0 then
        return results
    end
    local summary = { loaded = 0, failed = 0, names = {} }
    local ok, loopError = pcall(self._executePlans, self, plans, urlList, summary, results)
    if not ok then
        report("Error", "API", Loader:Resolve(loopError))
    end
    self:_reportSummary(summary)
    return results
end

-- // MiniFeatures Public
function Library:LoadMiniFeature(nameOrUrl, options)
    self = resolveWindow(self)
    if not requireWindow(self, "LoadMiniFeature") then
        return false
    end
    local results = self:_loadItems({ nameOrUrl }, options)
    return results[nameOrUrl] == true
end

function Library:LoadMiniFeatures(list, options)
    if type(list) == "string" then
        list = { list }
    end
    if type(list) ~= "table" then
        list = {}
    end
    self = resolveWindow(self)
    if not requireWindow(self, "LoadMiniFeatures") then
        local failed = {}
        for _, item in ipairs(list) do
            failed[item] = false
        end
        return failed
    end
    return self:_loadItems(list, options)
end

function Library:LoadAllMiniFeatures(options)
    self = resolveWindow(self)
    if not requireWindow(self, "LoadAllMiniFeatures") then
        return {}
    end
    return self:_loadItems({ "all" }, options)
end

-- // MiniFeatures Alias
Library.LoadFeature = Library.LoadMiniFeature
Library.LoadFeatures = Library.LoadMiniFeatures
Library.LoadAllFeatures = Library.LoadAllMiniFeatures
Library.UnloadFeature = Library.UnloadMiniFeature
Library.UnloadAllFeatures = Library.UnloadAllMiniFeatures
Library.ListFeatures = Library.ListMiniFeatures
Library.GetLoadedFeatures = Library.GetLoadedMiniFeatures
Library.IsFeatureLoaded = Library.IsMiniFeatureLoaded
Library.RefreshFeatures = Library.RefreshMiniFeatures
Library.SetFeaturesSource = Library.SetMiniFeaturesSource

-- // MiniElements
local MiniElements = {
    List = {},
    Files = {}
}

local miniElementsSource = nil
local triedElements = {}

Library.MiniElements = MiniElements
Library.Create = create
Library.AddCorner = addCorner
Library.AddStroke = addStroke
Library.IsPointerInput = isPointerInput
Library.IsMoveInput = isMoveInput

MiniElements.SelfFiring = {}

local registeringFile = false

function MiniElements.Register(name, constructor)
    if type(name) ~= "string" or type(constructor) ~= "function" then
        return false
    end
    MiniElements.List[name] = constructor
    MiniElements.SelfFiring[name] = registeringFile or nil
    return true
end

function Library:SetMiniElementsSource(url)
    local source = newSource(url)
    if not source then
        return false
    end
    miniElementsSource = source
    Library.MiniElementsSource = url
    Library.MiniElementsUrl = source.RawUrl
    return true
end

Library:SetMiniElementsSource("https://github.com/pvpgalinhamonzonrebasexk/monzonrebasexk/tree/main/Library/Elements")

local settingsSource = newSource("https://github.com/pvpgalinhamonzonrebasexk/monzonrebasexk/tree/main/MiniLibrarys")

Library.SettingsSource = "https://github.com/pvpgalinhamonzonrebasexk/monzonrebasexk/tree/main/MiniLibrarys"

function Library:SetSettingsSource(url)
    local source = newSource(url)
    if not source then
        return false
    end
    settingsSource = source
    Library.SettingsSource = url
    return true
end

-- // MiniElements Environment
local elementNotify = function(info)
    if type(info) == "table" then
        report("Warning", "Element", info.Description or info.Content or info.Title)
    else
        report("Warning", "Element", info)
    end
end

local elementGlobals = {
    Elements = MiniElements,
    Notify = elementNotify,
    FONT = Enum.Font.BuilderSans,
    FONT_BOLD = Enum.Font.BuilderSansBold,
    ICONS = { assets = IconTable },
    Icon = resolveIcon,
    TweenService = TweenService,
    UserInputService = UserInputService,
    Players = Players,
    HttpService = HttpService
}

Library.ElementGlobals = elementGlobals

local sandboxElement = function(fn)
    local env = getEnv()
    if setfenv then
        local ok = pcall(setfenv, fn, setmetatable(elementGlobals, { __index = env }))
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

-- // MiniElements Loader
local runElement = function(source, key, scriptName)
    triedElements[key] = true
    local fn, compileError = Loader:Compile(source, scriptName or ("Elements/" .. key))
    if not fn then
        report("Error", key, Loader:Resolve(compileError))
        return false
    end
    local env = getEnv()
    env.MiniElements = MiniElements
    env.Elements = MiniElements
    env.MiniLibrary = Library
    if not scriptName then
        sandboxElement(fn)
    end
    registeringFile = scriptName == nil
    local ok, runError = pcall(fn)
    registeringFile = false
    if not ok then
        report("Error", key, Loader:Resolve(runError))
        return false
    end
    MiniElements.Files[key] = true
    return true
end

function Library:LoadMiniElements(force)
    local entries = scopedEntries(miniElementsSource, force == true)
    if not entries then
        report("Warning", "MiniElements", "GitHub index unavailable, loading on demand")
        return false
    end
    local targets = {}
    local urls = {}
    for _, entry in ipairs(entries) do
        if force or not MiniElements.Files[entry.key] then
            local url = miniElementsSource.RawUrl .. encodePath(entry.path)
            targets[#targets + 1] = { key = entry.key, url = url }
            urls[#urls + 1] = url
        end
    end
    if #targets == 0 then
        return true
    end
    local bodies, reasons = fetchAll(urls)
    local failed = {}
    for _, target in ipairs(targets) do
        local body = bodies[target.url]
        if body then
            if not runElement(body, target.key) then
                failed[#failed + 1] = target.key
            end
            task.wait()
        else
            local why = tostring(reasons[target.url] or "unknown")
            failed[#failed + 1] = target.key .. " (" .. why .. ")"
        end
    end
    table.clear(bodies)
    if #failed > 0 then
        report("Warning", "MiniElements", "Failed: " .. table.concat(failed, ", "))
        return false
    end
    return true
end

function Library:_loadMissingElement(name)
    if MiniElements.List[name] or triedElements[name] then
        return MiniElements.List[name]
    end
    triedElements[name] = true
    local sources = {
        { source = miniElementsSource },
        { source = settingsSource, scriptName = "Settings" }
    }
    local loaded = false
    for _, item in ipairs(sources) do
        local source = item.source
        local entries = nil
        if not loaded and name ~= "*" and name:lower() ~= "all" then
            entries = scopedEntries(source, false)
        end
        if entries then
            local matches = matchMiniFeatureFiles(entries, name)
            for _, entry in ipairs(matches) do
                if not MiniElements.Files[entry.key] then
                    local body = fetchSource(source.RawUrl .. encodePath(entry.path))
                    if body and runElement(body, entry.key, item.scriptName) then
                        loaded = true
                    end
                end
            end
        end
    end
    if not loaded and not MiniElements.List[name] then
        for _, item in ipairs(sources) do
            local found = false
            for _, path in ipairs(miniFeatureCandidates(name)) do
                local body = fetchSource(item.source.RawUrl .. encodePath(path))
                if body then
                    runElement(body, stripExtension(path), item.scriptName and stripExtension(path) or nil)
                    found = true
                    break
                end
            end
            if found then
                break
            end
        end
    end
    return MiniElements.List[name]
end

function Library:ListMiniElements()
    local list = {}
    for name in pairs(MiniElements.List) do
        list[#list + 1] = name
    end
    table.sort(list)
    return list
end

Library.Elements = MiniElements
Library.LoadElements = Library.LoadMiniElements
Library.ListElements = Library.ListMiniElements
Library.SetElementsSource = Library.SetMiniElementsSource

-- // MiniElements Sections
local resolveName = function(options)
    if type(options) ~= "table" then
        return ""
    end
    return tostring(options.Name or options.Title or options.Text or "")
end

local createLabel = function(parent, text, space)
    return create("TextLabel", {
        Size = UDim2.new(1, -(space or 0), 1, 0),
        BackgroundTransparency = 1,
        Text = tostring(text or ""),
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    }, parent)
end

Library.CreateLabel = createLabel
Library.ResolveName = resolveName

local protectOptions = function(options, label)
    if type(options) ~= "table" then
        return options
    end
    local copy = {}
    for key, value in pairs(options) do
        copy[key] = value
    end
    for _, callbackKey in ipairs({
        "Callback", "callback", "OnCommit", "onCommit", "OnSubmit", "onSubmit", "KeybindCallback", "keybindCallback"
    }) do
        local callback = copy[callbackKey]
        if type(callback) == "function" then
            copy[callbackKey] = function(...)
                local ok, result = pcall(callback, ...)
                if not ok then
                    report("Error", label, Loader:Resolve(result))
                    return nil
                end
                return result
            end
        end
    end
    return copy
end

local createFlag = function(sectionData, constructorName, options)
    if type(options) ~= "table" or options.Save == false then
        return nil
    end
    if constructorName == "Button" or constructorName == "Paragraph" then
        return nil
    end
    if type(options.Flag) == "string" and options.Flag ~= "" then
        return options.Flag
    end
    local label = resolveName(options)
    if label == "" then
        label = constructorName
    end
    local tabName = sectionData.Tab and sectionData.Tab.name or "Tab"
    local base = tabName .. "/" .. tostring(sectionData.title) .. "/" .. label
    local counts = sectionData.flagCounts
    counts[base] = (counts[base] or 0) + 1
    if counts[base] > 1 then
        return base .. "#" .. counts[base]
    end
    return base
end

-- // Element Paint
local isUnpainted = function(color)
    local isWhite = color.R > 0.95 and color.G > 0.95 and color.B > 0.95
    local isDefault = math.abs(color.R - 0.639) < 0.01
        and math.abs(color.G - 0.635) < 0.01
        and math.abs(color.B - 0.647) < 0.01
    return isWhite or isDefault
end

local isRowBackground = function(object)
    local size = object.Size
    return size.X.Scale >= 0.99 and size.Y.Offset >= 24
end

local paintObject = function(object)
    if not object or not object.Parent then
        return
    end
    local paintable = object:IsA("Frame")
        or object:IsA("TextButton")
        or object:IsA("TextBox")
        or object:IsA("ScrollingFrame")
    if not paintable then
        return
    end
    if object.BackgroundTransparency >= 0.9 then
        return
    end
    if not isRowBackground(object) then
        return
    end
    if isUnpainted(object.BackgroundColor3) then
        object.BackgroundColor3 = Theme.Card
        object.BackgroundTransparency = 0
    end
end

local paintHolder = function(holder)
    holder.DescendantAdded:Connect(function(descendant)
        task.defer(paintObject, descendant)
    end)
    for _, descendant in ipairs(holder:GetDescendants()) do
        paintObject(descendant)
    end
end

Library.PaintObject = paintObject

-- // Element Options
local ElementAliases = {
    Checkbox = "Toggle",
    Switch = "Toggle",
    TextBox = "Input",
    Label = "Paragraph"
}

local normalizeOptions = function(options)
    local source = type(options) == "table" and options or { Name = options }
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    if copy.Default == nil then
        for _, key in ipairs({ "Value", "CurrentValue", "Enabled", "Color", "Selected" }) do
            if copy[key] ~= nil then
                copy.Default = copy[key]
                break
            end
        end
    end
    copy.Step = copy.Step or copy.Increment
    copy.Values = copy.Values or copy.Options or copy.Items or copy.List
    copy.Description = copy.Description or copy.Desc
    if type(copy.Range) == "table" then
        copy.Min = copy.Min or copy.Range[1]
        copy.Max = copy.Max or copy.Range[2]
    end
    for _, key in ipairs({ "Function", "OnChanged", "OnChange", "Changed" }) do
        if copy.Callback == nil and type(copy[key]) == "function" then
            copy.Callback = copy[key]
        end
    end
    local extra = {}
    for key, value in pairs(copy) do
        if type(key) == "string" and key ~= "" then
            local lower = key:sub(1, 1):lower() .. key:sub(2)
            local upper = key:sub(1, 1):upper() .. key:sub(2)
            if lower ~= key and copy[lower] == nil then
                extra[lower] = value
            end
            if upper ~= key and copy[upper] == nil then
                extra[upper] = value
            end
        end
    end
    for key, value in pairs(extra) do
        if copy[key] == nil then
            copy[key] = value
        end
    end
    return copy
end

Library.ElementAliases = ElementAliases

-- // Element Language
local localizedObjects = setmetatable({}, { __mode = "k" })

local localizeObject = function(window, object, full)
    if localizedObjects[object] then
        return
    end
    local isBox = object:IsA("TextBox")
    if not (isBox or object:IsA("TextLabel") or object:IsA("TextButton")) then
        return
    end
    localizedObjects[object] = true
    local property = isBox and "PlaceholderText" or "Text"
    local state = {
        Source = object[property],
        Full = full,
        Last = nil
    }
    local apply = function()
        if state.Source == "" then
            state.Last = nil
            return
        end
        local translated = window:Translate(state.Source, not state.Full)
        state.Last = translated
        if object[property] ~= translated then
            object[property] = translated
        end
    end
    object:GetPropertyChangedSignal(property):Connect(function()
        local current = object[property]
        if current == state.Last then
            return
        end
        state.Source = current
        state.Full = false
        apply()
    end)
    window:OnLanguageChanged(apply)
    apply()
end

local watchLanguage = function(window, holder)
    local ready = false
    holder.DescendantAdded:Connect(function(descendant)
        if ready then
            task.defer(localizeObject, window, descendant, false)
        end
    end)
    return function()
        ready = true
        for _, descendant in ipairs(holder:GetDescendants()) do
            localizeObject(window, descendant, true)
        end
    end
end

-- // Element Resolve
local ElementPrefer = {
    Toggle = "Checkbox",
    Switch = "Checkbox"
}

local resolveConstructor = function(constructorName)
    local prefer = ElementPrefer[constructorName]
    if prefer then
        local preferred = MiniElements.List[prefer] or Library:_loadMissingElement(prefer)
        if preferred then
            return preferred, prefer
        end
    end
    local resolved = constructorName
    local constructor = MiniElements.List[resolved]
    if not constructor then
        local alias = ElementAliases[constructorName]
        if alias and MiniElements.List[alias] then
            resolved = alias
            constructor = MiniElements.List[alias]
        end
    end
    if not constructor then
        resolved = constructorName
        constructor = Library:_loadMissingElement(constructorName)
    end
    return constructor, resolved
end

local buildElement = function(window, sectionData, constructorName, options)
    options = normalizeOptions(options)
    local constructor, resolvedName = resolveConstructor(constructorName)
    if not constructor then
        report("Error", "MiniElements", constructorName .. " is not registered")
        return nil
    end
    local holderSection, holder = sectionData:NewHolder(constructorName)
    local label = resolveName(options)
    if label == "" then
        label = constructorName
    end
    local flag = createFlag(sectionData, constructorName, options)
    local protected = protectOptions(options, label)
    paintHolder(holder)
    local finishLanguage = watchLanguage(window, holder)
    local ok, result = pcall(constructor, holderSection, protected)
    if not ok then
        holder:Destroy()
        report("Error", constructorName .. " | " .. label, Loader:Resolve(result))
        return nil
    end
    finishLanguage()
    local saveable = type(result) == "table" and type(result.Get) == "function" and type(result.Set) == "function"
    if flag and saveable and type(window.flags) == "table" then
        local callback = type(protected) == "table" and protected.Callback or nil
        window:_registerFlag(flag, result, callback, MiniElements.SelfFiring[resolvedName] == true)
    end
    return result or holder
end

local attachElementMethods = function(window, sectionData)
    function sectionData:CreateElement(name, options)
        return buildElement(window, sectionData, name, options)
    end
    setmetatable(sectionData, {
        __index = function(_, key)
            if type(key) ~= "string" then
                return nil
            end
            local name = key:match("^Create(%w+)$")
            if not name then
                return nil
            end
            return function(_, options)
                return buildElement(window, sectionData, name, options)
            end
        end
    })
end

-- // Section
function Library:_createSection(tab, title)
    local window = self
    tab.sectionCount = tab.sectionCount + 1
    title = tostring(title or "Section")
    local frame = create("Frame", {
        Name = title,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Card,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        LayoutOrder = tab.sectionCount
    }, tab.Page)
    addCorner(frame, 6)
    addStroke(frame, Theme.Line, 1)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10)
    }, frame)
    create("UIListLayout", {
        Padding = UDim.new(0, Metrics.ElementGap),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, frame)
    local titleKey = title
    local titleLabel = create("TextLabel", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = upperText(window:Translate(titleKey)),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = Color3.fromRGB(130, 130, 140),
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = title ~= "",
        LayoutOrder = 0
    }, frame)
    window:OnLanguageChanged(function()
        titleLabel.Text = upperText(window:Translate(titleKey))
    end)
    local sectionData = {
        Frame = frame,
        frame = frame,
        Window = window,
        window = window,
        Tab = tab,
        title = title,
        flagCounts = {},
        elementCount = 0
    }
    function sectionData:SetTitle(text)
        titleKey = tostring(text)
        titleLabel.Text = upperText(window:Translate(titleKey))
        titleLabel.Visible = titleKey ~= ""
    end
    function sectionData:Connect(signal, callback)
        return window:_connect(signal, callback)
    end
    function sectionData:NewHolder(name)
        sectionData.elementCount = sectionData.elementCount + 1
        local holder = create("Frame", {
            Name = tostring(name),
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = sectionData.elementCount
        }, frame)
        create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder
        }, holder)
        local holderSection = setmetatable({
            Frame = holder,
            frame = holder,
            Window = window,
            window = window
        }, {
            __index = sectionData
        })
        return holderSection, holder
    end
    attachElementMethods(window, sectionData)
    return sectionData
end

-- // Storage
Library.Folder = "Ecohub"

Library.EnsureFolder = function()
    if not (isfolder and makefolder) then
        return false
    end
    local ok, exists = pcall(isfolder, Library.Folder)
    if ok and exists then
        return true
    end
    return pcall(makefolder, Library.Folder)
end

Library.DataFile = function()
    return Library.Folder .. "/" .. tostring(game.PlaceId) .. ".json"
end

Library.ConfigFile = Library.DataFile

-- // Pretty Encoder
local JsonIndent = "    "

local JsonPriority = {
    Settings = 1,
    Config = 2,
    Translations = 3,
    Tab = 4,
    Elements = 5
}

local escapeText = function(text)
    local escaped = text:gsub('[%c"\\]', function(character)
        if character == '"' then
            return '\\"'
        end
        if character == "\\" then
            return "\\\\"
        end
        if character == "\n" then
            return "\\n"
        end
        if character == "\r" then
            return "\\r"
        end
        if character == "\t" then
            return "\\t"
        end
        return string.format("\\u%04x", character:byte())
    end)
    return '"' .. escaped .. '"'
end

local sortedKeys = function(source)
    local keys = {}
    for key in pairs(source) do
        keys[#keys + 1] = tostring(key)
    end
    table.sort(keys, function(a, b)
        local first = JsonPriority[a] or math.huge
        local second = JsonPriority[b] or math.huge
        if first ~= second then
            return first < second
        end
        return a < b
    end)
    return keys
end

local encodePretty = nil

encodePretty = function(value, depth)
    local kind = type(value)
    if kind == "string" then
        return escapeText(value)
    end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return "0"
        end
        return string.format("%.14g", value)
    end
    if kind == "boolean" then
        return tostring(value)
    end
    if kind ~= "table" then
        return "null"
    end
    if next(value) == nil then
        return "{}"
    end
    local inner = string.rep(JsonIndent, depth + 1)
    local outer = string.rep(JsonIndent, depth)
    local parts = {}
    if #value > 0 then
        for index, item in ipairs(value) do
            parts[index] = inner .. encodePretty(item, depth + 1)
        end
        return "[\n" .. table.concat(parts, ",\n") .. "\n" .. outer .. "]"
    end
    for _, key in ipairs(sortedKeys(value)) do
        parts[#parts + 1] = inner .. escapeText(key) .. ": " .. encodePretty(value[key], depth + 1)
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. outer .. "}"
end

-- // Flag Groups
local isGroup = function(value)
    return type(value) == "table" and #value == 0 and next(value) ~= nil
end

local nestFlags = function(elements)
    local root = {}
    local flags = {}
    for flag in pairs(elements) do
        flags[#flags + 1] = tostring(flag)
    end
    table.sort(flags)
    for _, flag in ipairs(flags) do
        local segments = {}
        for segment in flag:gmatch("[^/]+") do
            segments[#segments + 1] = segment
        end
        if #segments == 0 then
            segments[1] = flag
        end
        local node = root
        local index = 1
        while index < #segments do
            local child = node[segments[index]]
            if child == nil then
                child = {}
                node[segments[index]] = child
            elseif not isGroup(child) then
                break
            end
            node = child
            index = index + 1
        end
        node[table.concat(segments, "/", index)] = elements[flag]
    end
    return root
end

local flattenFlags = nil

flattenFlags = function(node, prefix, output)
    for key, value in pairs(node) do
        local path = prefix == "" and tostring(key) or (prefix .. "/" .. tostring(key))
        if isGroup(value) then
            flattenFlags(value, path, output)
        else
            output[path] = value
        end
    end
    return output
end

-- // Data Store
local DataStore = {
    Data = nil
}

Library.DataStore = DataStore

local newData = function()
    return {
        Settings = {},
        Config = { Elements = {}, Tab = nil },
        Translations = {}
    }
end

local readFileData = function(path)
    if not (isfile and readfile) then
        return nil
    end
    local ok, saved = pcall(function()
        if not isfile(path) then
            return nil
        end
        return HttpService:JSONDecode(readfile(path))
    end)
    if ok and type(saved) == "table" then
        return saved
    end
    return nil
end

local migrateLegacy = function(data)
    local migrated = false
    local legacy = {
        Settings = "Settings.json",
        Translations = "Translations.json"
    }
    for section, name in pairs(legacy) do
        local path = Library.Folder .. "/" .. name
        local saved = readFileData(path)
        if saved then
            migrated = true
            if next(data[section]) == nil then
                data[section] = saved
            end
            if delfile then
                pcall(delfile, path)
            end
        end
    end
    return migrated
end

function DataStore.Read()
    local data = newData()
    local saved = readFileData(Library.DataFile())
    if not saved then
        return data, false
    end
    if type(saved.Settings) == "table" then
        data.Settings = saved.Settings
    end
    if type(saved.Translations) == "table" then
        data.Translations = saved.Translations
    end
    local source = type(saved.Config) == "table" and saved.Config or saved
    if type(source.Elements) == "table" then
        flattenFlags(source.Elements, "", data.Config.Elements)
    end
    if type(source.Tab) == "string" then
        data.Config.Tab = source.Tab
    end
    return data, true
end

function DataStore.Load(force)
    if DataStore.Data and not force then
        return DataStore.Data
    end
    local data = DataStore.Read()
    DataStore.Data = data
    if migrateLegacy(data) then
        DataStore.Save()
    end
    return data
end

function DataStore.Save(parts)
    if not writefile then
        return false
    end
    local data = DataStore.Load()
    if type(parts) == "table" then
        for section, value in pairs(parts) do
            data[section] = value
        end
    end
    Library.EnsureFolder()
    local output = {
        Settings = data.Settings,
        Config = {
            Tab = data.Config.Tab,
            Elements = nestFlags(data.Config.Elements)
        },
        Translations = data.Translations
    }
    local ok = pcall(function()
        writefile(Library.DataFile(), encodePretty(output, 0))
    end)
    return ok
end

-- // Translation
Library.Locale = {
    Languages = {
        { Value = "en", Text = "English" },
        { Value = "pt", Text = "Português (BR)" }
    },
    Strings = {
        en = {},
        pt = {}
    }
}

function Library:Translate(key)
    if key == nil then
        return ""
    end
    if type(key) ~= "string" then
        return tostring(key)
    end
    local strings = Library.Locale.Strings
    local pack = strings[Library.CurrentLanguage]
    local value = pack and pack[key]
    if value == nil then
        local base = strings.en
        value = base and base[key]
    end
    if value == nil then
        value = Library:_autoTranslate(key)
    end
    return value or key
end

function Library:OnLanguageChanged(callback)
    if type(callback) ~= "function" then
        return nil
    end
    local listeners = Library.LanguageListeners
    listeners[#listeners + 1] = callback
    return {
        Disconnect = function()
            local index = table.find(listeners, callback)
            if index then
                table.remove(listeners, index)
            end
        end
    }
end

function Library:BindText(setter, key)
    if type(setter) ~= "function" then
        return nil
    end
    local apply = function()
        pcall(setter, Library:Translate(key))
    end
    apply()
    return Library:OnLanguageChanged(apply)
end

function Library:_notifyLanguage()
    local snapshot = {}
    for index, listener in ipairs(Library.LanguageListeners) do
        snapshot[index] = listener
    end
    for _, listener in ipairs(snapshot) do
        pcall(listener, Library.CurrentLanguage)
    end
end

function Library:_refreshLanguageList()
    local window = getEnv().__MiniWindow
    if window and window.languageControl then
        pcall(window.languageControl.SetValues, window.languageControl, Library.Locale.Languages)
    end
end

function Library:AddTranslations(code, strings)
    if type(code) ~= "string" or type(strings) ~= "table" then
        return false
    end
    local locale = Library.Locale
    local pack = locale.Strings[code]
    if not pack then
        pack = {}
        locale.Strings[code] = pack
        locale.Languages[#locale.Languages + 1] = { Value = code, Text = code }
        Library:_refreshLanguageList()
    end
    for key, value in pairs(strings) do
        pack[tostring(key)] = tostring(value)
    end
    if code == Library.CurrentLanguage then
        Library:_notifyLanguage()
    end
    return true
end

function Library:RegisterLanguage(code, displayName, strings)
    if type(code) ~= "string" or code == "" then
        return false
    end
    local locale = Library.Locale
    if not locale.Strings[code] then
        locale.Strings[code] = {}
    end
    local found = false
    for _, language in ipairs(locale.Languages) do
        if language.Value == code then
            language.Text = tostring(displayName or language.Text)
            found = true
        end
    end
    if not found then
        locale.Languages[#locale.Languages + 1] = { Value = code, Text = tostring(displayName or code) }
    end
    if type(strings) == "table" then
        Library:AddTranslations(code, strings)
    end
    Library:_refreshLanguageList()
    return true
end

function Library:GetLanguage()
    return Library.CurrentLanguage
end

function Library:GetLanguages()
    local list = {}
    for _, language in ipairs(Library.Locale.Languages) do
        list[#list + 1] = language.Value
    end
    return list
end

function Library:SetLanguage(code, persist)
    if type(code) ~= "string" or not Library.Locale.Strings[code] then
        code = "en"
    end
    Library.CurrentLanguage = code
    if type(Library._resetTranslator) == "function" then
        Library:_resetTranslator()
    end
    local window = isWindow(self) and self or getEnv().__MiniWindow
    if window and window.settings then
        window.settings.Language = code
    end
    Library:_notifyLanguage()
    if persist ~= false and window and window._saveSettings then
        window:_saveSettings()
    end
end

-- // Translator
Library.TranslatorConfig = {
    Enabled = true,
    Source = "en",
    Email = nil,
    Delay = 0.05,
    Workers = 4,
    MaxAttempts = 3,
    MaxQueue = 600,
    MaxLength = 450,
    RetryAfter = 60,
    Cooldown = 600,
    Providers = { "Google", "MyMemory" },
    Codes = {
        MyMemory = { pt = "pt-BR" },
        Google = { pt = "pt" }
    }
}

local translatorState = {
    Queue = {},
    Pending = {},
    Failed = {},
    Blocked = {},
    Ignored = {},
    Dirty = false,
    Workers = 0,
    Sweeps = 0,
    Failures = 0,
    Changed = false,
    LastNotify = 0
}

local Providers = {}

local getPack = function(language, create)
    local translations = DataStore.Load().Translations
    local pack = translations[language]
    if not pack and create then
        pack = {}
        translations[language] = pack
    end
    return pack
end

local saveTranslatorCache = function()
    translatorState.Dirty = false
    DataStore.Save()
end

local shouldTranslate = function(text)
    if #text < 2 or #text > Library.TranslatorConfig.MaxLength then
        return false
    end
    if translatorState.Ignored[text] then
        return false
    end
    if not text:find("%a") then
        return false
    end
    if text:find("%d") or text:find("\\") or text:find("^https?:") then
        return false
    end
    if not text:find("%s") then
        local isPath = text:find("/") ~= nil
        local isCamel = text:find("%l%u") ~= nil
        local isFile = text:find("%.%a+$") ~= nil
        local isAcronym = text:upper() == text
        if isPath or isCamel or isFile or isAcronym then
            return false
        end
    end
    for _, language in ipairs(Library.Locale.Languages) do
        if language.Text == text then
            return false
        end
    end
    return true
end

local decodeEntities = function(text)
    text = text:gsub("&#(%d+);", function(code)
        local ok, character = pcall(utf8.char, tonumber(code))
        return ok and character or ""
    end)
    text = text:gsub("&quot;", '"')
    text = text:gsub("&lt;", "<")
    text = text:gsub("&gt;", ">")
    text = text:gsub("&amp;", "&")
    return text
end

local translatorGet = function(url)
    local httpRequest = request or http_request or (syn and syn.request)
    local ok, body = pcall(function()
        if httpRequest then
            local response = httpRequest({ Url = url, Method = "GET" })
            if type(response) == "table" and (response.StatusCode == 200 or response.Success == true) then
                return response.Body
            end
            return nil
        end
        return game:HttpGet(url)
    end)
    if ok and type(body) == "string" then
        return body
    end
    return nil
end

-- // Translator Providers
function Providers.MyMemory(text, target)
    local config = Library.TranslatorConfig
    local code = config.Codes.MyMemory[target] or target
    local url = "https://api.mymemory.translated.net/get?q=" .. HttpService:UrlEncode(text)
        .. "&langpair=" .. HttpService:UrlEncode(config.Source .. "|" .. code)
    if config.Email then
        url = url .. "&de=" .. HttpService:UrlEncode(config.Email)
    end
    local body = translatorGet(url)
    if not body then
        return nil, "no response", false
    end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
    if not ok or type(data) ~= "table" or type(data.responseData) ~= "table" then
        return nil, "invalid response", false
    end
    local translated = data.responseData.translatedText
    local status = tonumber(data.responseStatus)
    if status ~= 200 then
        return nil, tostring(data.responseDetails or "failed"), status == 429
    end
    if type(translated) ~= "string" or translated == "" then
        return nil, "empty", false
    end
    if translated:upper():find("MYMEMORY WARNING", 1, true) then
        return nil, "quota", true
    end
    return decodeEntities(translated)
end

function Providers.Google(text, target)
    local config = Library.TranslatorConfig
    local code = config.Codes.Google[target] or target
    local url = "https://translate.googleapis.com/translate_a/single?client=gtx&dt=t&sl=" .. config.Source
        .. "&tl=" .. code .. "&q=" .. HttpService:UrlEncode(text)
    local body = translatorGet(url)
    if not body then
        return nil, "no response", false
    end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
    if not ok or type(data) ~= "table" or type(data[1]) ~= "table" then
        return nil, "invalid response", false
    end
    local parts = {}
    for _, segment in ipairs(data[1]) do
        if type(segment) == "table" and type(segment[1]) == "string" then
            parts[#parts + 1] = segment[1]
        end
    end
    local translated = table.concat(parts)
    if translated == "" then
        return nil, "empty", false
    end
    return translated
end

-- // Translator Queue
local requestTranslation = function(text, target)
    local config = Library.TranslatorConfig
    for _, name in ipairs(config.Providers) do
        local provider = Providers[name]
        local blockedAt = translatorState.Blocked[name]
        local blocked = blockedAt and os.clock() - blockedAt < config.Cooldown
        if provider and not blocked then
            local ok, result, _, limited = pcall(provider, text, target)
            if ok and result then
                return result
            end
            if ok and limited then
                translatorState.Blocked[name] = os.clock()
            end
        end
    end
    return nil
end

local isActiveLibrary = function()
    return getEnv().MiniLibrary == Library
end

local notifyTranslator = function(force)
    local state = translatorState
    if not state.Changed then
        return
    end
    if force or os.clock() - state.LastNotify > 1.5 then
        state.Changed = false
        state.LastNotify = os.clock()
        Library:_notifyLanguage()
    end
end

local processTranslation = function(job)
    local state = translatorState
    local config = Library.TranslatorConfig
    local key = job.Language .. "\n" .. job.Text
    state.Pending[key] = nil
    if job.Language ~= Library.CurrentLanguage then
        return
    end
    local result = requestTranslation(job.Text, job.Language)
    if result then
        getPack(job.Language, true)[job.Text] = result
        state.Dirty = true
        state.Changed = true
        return
    end
    local attempt = job.Attempt or 1
    if attempt < config.MaxAttempts then
        state.Pending[key] = true
        state.Queue[#state.Queue + 1] = { Text = job.Text, Language = job.Language, Attempt = attempt + 1 }
        task.wait(0.5 * attempt)
        return
    end
    state.Failed[key] = os.clock()
    state.Failures = state.Failures + 1
end

local finishTranslatorQueue = function()
    local state = translatorState
    if not isActiveLibrary() then
        return
    end
    notifyTranslator(true)
    if state.Dirty then
        saveTranslatorCache()
    end
    if state.Failures > 0 and state.Sweeps < 3 then
        state.Failures = 0
        state.Sweeps = state.Sweeps + 1
        local language = Library.CurrentLanguage
        task.delay(Library.TranslatorConfig.RetryAfter + 1, function()
            if isActiveLibrary() and Library.CurrentLanguage == language then
                Library:_notifyLanguage()
            end
        end)
    end
end

local runTranslatorQueue = function()
    local state = translatorState
    local config = Library.TranslatorConfig
    local wanted = math.min(config.Workers, #state.Queue)
    while state.Workers < wanted do
        state.Workers = state.Workers + 1
        task.spawn(function()
            while #state.Queue > 0 and isActiveLibrary() do
                local job = table.remove(state.Queue, 1)
                local ok, failure = pcall(processTranslation, job)
                if not ok then
                    report("Error", "Translator", tostring(failure))
                end
                notifyTranslator(false)
                task.wait(config.Delay)
            end
            state.Workers = state.Workers - 1
            if state.Workers == 0 then
                finishTranslatorQueue()
            end
        end)
    end
end

function Library:_resetTranslator()
    local state = translatorState
    state.Queue = {}
    state.Pending = {}
    state.Failed = {}
    state.Failures = 0
    state.Sweeps = 0
end

-- // Translator API
function Library:_autoTranslate(text)
    local config = Library.TranslatorConfig
    local language = Library.CurrentLanguage
    if not config.Enabled or language == config.Source then
        return nil
    end
    local pack = getPack(language, false)
    local cached = pack and pack[text]
    if cached then
        return cached
    end
    if not shouldTranslate(text) then
        return nil
    end
    local key = language .. "\n" .. text
    if translatorState.Pending[key] then
        return nil
    end
    if #translatorState.Queue >= config.MaxQueue then
        return nil
    end
    local failedAt = translatorState.Failed[key]
    if failedAt and os.clock() - failedAt < config.RetryAfter then
        return nil
    end
    translatorState.Pending[key] = true
    translatorState.Queue[#translatorState.Queue + 1] = { Text = text, Language = language }
    runTranslatorQueue()
    return nil
end

function Library:SetTranslator(options)
    if type(options) ~= "table" then
        return false
    end
    local config = Library.TranslatorConfig
    for _, field in ipairs({ "Enabled", "Source", "Email", "Delay", "MaxLength", "Providers", "Workers", "MaxAttempts", "MaxQueue" }) do
        if options[field] ~= nil then
            config[field] = options[field]
        end
    end
    return true
end

function Library:IgnoreTranslation(list)
    if type(list) == "string" then
        list = { list }
    end
    if type(list) ~= "table" then
        return false
    end
    for _, text in ipairs(list) do
        translatorState.Ignored[tostring(text)] = true
    end
    return true
end

function Library:ClearTranslationCache()
    DataStore.Load().Translations = {}
    translatorState.Failed = {}
    translatorState.Dirty = false
    DataStore.Save()
    Library:_notifyLanguage()
    return true
end

-- // Config
local isPrimitive = function(value)
    local kind = type(value)
    if kind == "number" then
        return value == value and value ~= math.huge and value ~= -math.huge
    end
    return kind == "boolean" or kind == "string"
end

local encodeValue = function(value)
    if isPrimitive(value) then
        return value
    end
    if typeof(value) == "Color3" then
        return "#" .. value:ToHex():upper()
    end
    if type(value) == "table" then
        local list = {}
        for _, item in ipairs(value) do
            if isPrimitive(item) then
                list[#list + 1] = item
            end
        end
        return list
    end
    return nil
end

local signature = function(config)
    local keys = {}
    for key in pairs(config.Elements) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    local parts = { tostring(config.Tab) }
    for _, key in ipairs(keys) do
        local value = config.Elements[key]
        if type(value) == "table" then
            local items = {}
            for index, item in ipairs(value) do
                items[index] = tostring(item)
            end
            value = "[" .. table.concat(items, ",") .. "]"
        end
        parts[#parts + 1] = key .. "=" .. tostring(value)
    end
    return table.concat(parts, "\n")
end

function Library:_readConfig()
    local data, exists = DataStore.Read()
    return data.Config, exists
end

function Library:_collectConfig()
    local elements = self.config.Elements
    for flag, entry in pairs(self.flags) do
        local ok, value = pcall(entry.object.Get, entry.object)
        if ok then
            local encoded = encodeValue(value)
            if encoded ~= nil then
                elements[flag] = encoded
            end
        end
    end
end

function Library:SaveConfig(onlyIfChanged)
    if self.destroyed or not writefile then
        return false
    end
    self:_collectConfig()
    local current = signature(self.config)
    if onlyIfChanged == true and current == self.lastSignature then
        return true
    end
    local ok = DataStore.Save({ Config = self.config })
    if ok then
        self.lastSignature = current
    end
    return ok
end

function Library:_applyFlag(entry, value)
    local ok = pcall(entry.object.Set, entry.object, value, false)
    if not ok then
        return
    end
    local callback = entry.callback
    if callback and not entry.selfFiring then
        task.defer(function()
            local gotValue, current = pcall(entry.object.Get, entry.object)
            if gotValue then
                pcall(callback, current)
            end
        end)
    end
end

function Library:_registerFlag(flag, object, callback, selfFiring)
    local entry = { object = object, callback = callback, selfFiring = selfFiring == true }
    self.flags[flag] = entry
    local saved = self.config.Elements[flag]
    if saved ~= nil then
        self:_applyFlag(entry, saved)
    end
end

function Library:LoadConfig()
    local data, exists = Library:_readConfig()
    if not exists then
        return false
    end
    self.config.Elements = data.Elements
    for flag, entry in pairs(self.flags) do
        local value = data.Elements[flag]
        if value ~= nil then
            self:_applyFlag(entry, value)
        end
    end
    self.lastSignature = signature(self.config)
    return true
end

function Library:DeleteConfig()
    self.config = { Elements = {}, Tab = self.config and self.config.Tab or nil }
    local ok = DataStore.Save({ Config = self.config })
    self.lastSignature = nil
    return ok
end

function Library:GetConfigFile()
    return Library.ConfigFile()
end

function Library:GetFlag(flag)
    local entry = self.flags[flag]
    if entry then
        local ok, value = pcall(entry.object.Get, entry.object)
        if ok then
            return value
        end
    end
    return self.config.Elements[flag]
end

function Library:SetFlag(flag, value, fire)
    local entry = self.flags[flag]
    if not entry then
        self.config.Elements[flag] = encodeValue(value)
        return false
    end
    pcall(entry.object.Set, entry.object, value, fire == true)
    return true
end

function Library:GetFlags()
    local list = {}
    for flag in pairs(self.flags) do
        list[#list + 1] = flag
    end
    table.sort(list)
    return list
end

function Library:_startAutoSave()
    task.spawn(function()
        while not self.destroyed do
            task.wait(1)
            if not self.destroyed and self.settings.AutoSave then
                self:SaveConfig(true)
            end
        end
    end)
end

-- // Connections
function Library:_connect(signal, callback)
    local connection = signal:Connect(callback)
    self.connections[#self.connections + 1] = connection
    return connection
end

-- // Settings
Library.DefaultSettings = {
    Side = "Right",
    Width = Metrics.DrawerWidth,
    Transparency = 0,
    MinimizeKey = "RightShift",
    Language = "en",
    AutoSave = true
}

Library.SettingsLimits = {
    Width = { Min = 260, Max = 420, Step = 10 },
    Transparency = { Min = 0, Max = 0.6, Step = 0.05 }
}

function Library:_keyFromName(name)
    if type(name) ~= "string" then
        return nil
    end
    local ok, key = pcall(function()
        return Enum.KeyCode[name]
    end)
    if ok and key then
        return key
    end
    local inputOk, inputType = pcall(function()
        return Enum.UserInputType[name]
    end)
    if inputOk and inputType then
        return inputType
    end
    return nil
end

function Library:_loadSettings()
    local settings = {}
    for key, value in pairs(Library.DefaultSettings) do
        settings[key] = value
    end
    local saved = DataStore.Load().Settings
    for key in pairs(settings) do
        if type(saved[key]) == type(settings[key]) then
            settings[key] = saved[key]
        end
    end
    local limits = Library.SettingsLimits
    settings.Side = settings.Side == "Left" and "Left" or "Right"
    settings.Width = math.clamp(settings.Width, limits.Width.Min, limits.Width.Max)
    settings.Transparency = math.clamp(settings.Transparency, limits.Transparency.Min, limits.Transparency.Max)
    if not Library.Locale.Strings[settings.Language] then
        settings.Language = Library.DefaultSettings.Language
    end
    return settings
end

function Library:_saveSettings()
    DataStore.Save({ Settings = self.settings })
end

function Library:_drawerPosition(open)
    local width = self.drawerWidth
    if self.settings.Side == "Left" then
        if open then
            return UDim2.new(0, 0, 0, 0)
        end
        return UDim2.new(0, -width, 0, 0)
    end
    if open then
        return UDim2.new(1, -width, 0, 0)
    end
    return UDim2.new(1, 0, 0, 0)
end

-- // Window
function Library:CreateWindow(config)
    config = type(config) == "table" and config or {}
    local env = getEnv()
    Library.EnsureFolder()
    local previous = env.__MiniWindow
    if previous and type(previous.Destroy) == "function" then
        pcall(previous.Destroy, previous)
    end
    DataStore.Load(true)
    table.clear(Library.LanguageListeners)
    cleanupGuis(getHui())
    cleanupGuis(CoreGui)
    cleanupGuis(PlayerGui)
    local window = setmetatable({
        Title = tostring(config.Title or "Mini"),
        SubTitle = tostring(config.SubTitle or config.Subtitle or ""),
        MinimizeKey = config.MinimizeKey or Enum.KeyCode.RightShift,
        settings = Library:_loadSettings(),
        config = Library:_readConfig(),
        flags = {},
        tabs = {},
        selectedTab = nil,
        connections = {},
        loadedMiniFeatures = {},
        isOpen = true,
        openToken = 0,
        destroyed = false
    }, Library)
    window.lastSignature = signature(window.config)
    Library:IgnoreTranslation({ window.Title, window.SubTitle })
    Library.CurrentLanguage = window.settings.Language
    env.__MiniWindow = window
    local savedKey = Library:_keyFromName(window.settings.MinimizeKey)
    if savedKey and not config.MinimizeKey then
        window.MinimizeKey = savedKey
    end
    window:_exposeGlobals()
    local ok, err = pcall(window._init, window)
    if not ok then
        report("Error", "Window", Loader:Resolve(err))
    end
    pcall(function()
        if isfile and writefile and not isfile(Library.ConfigFile()) then
            window:SaveConfig()
        end
    end)
    window:_startAutoSave()
    local elementsOk, elementsError = pcall(Library.LoadMiniElements, Library)
    if getEnv().__MiniWindow ~= window then
        return window
    end
    if not elementsOk then
        report("Error", "Elements", Loader:Resolve(elementsError))
    end
    if type(window.CreateSettingsTab) ~= "function" then
        local settingsOk, settingsError = pcall(Library.LoadSettings, Library)
        if not settingsOk then
            report("Error", "Settings", Loader:Resolve(settingsError))
        end
    end
    window:_exposeGlobals()
    return window
end

function Library.new(title, subtitle)
    return Library:CreateWindow({ Title = title, SubTitle = subtitle })
end

function Library:SetTitle(text)
    self.Title = tostring(text)
    Library:IgnoreTranslation(self.Title)
    if self.titleLabel then
        self.titleLabel.Text = self:Translate(self.Title)
    end
end

function Library:SetSubTitle(text)
    self.SubTitle = tostring(text)
    Library:IgnoreTranslation(self.SubTitle)
    if self.subtitleLabel then
        self.subtitleLabel.Text = self:Translate(self.SubTitle)
    end
end

-- // Window Init
function Library:_init()
    self.screenGui = create("ScreenGui", {
        Name = "DrawerMiniGui",
        ResetOnSpawn = false,
        DisplayOrder = 1000,
        IgnoreGuiInset = true
    })
    placeGui(self.screenGui)
    self.drawerWidth = math.min(self.settings.Width, getViewport().X)
    self:_createDrawer()
    self:_createToggleButton()
    if not isMobile() then
        self:_connect(UserInputService.InputBegan, function(input, gameProcessed)
            local matches = input.KeyCode == self.MinimizeKey or input.UserInputType == self.MinimizeKey
            if not gameProcessed and not self.capturingKey and matches then
                self:Toggle()
            end
        end)
    end
end

function Library:_createHeader()
    local header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, Metrics.HeaderHeight),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0
    }, self.drawerFrame)
    self.headerFrame = header
    create("Frame", {
        Name = "HeaderDivider",
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.Line,
        BorderSizePixel = 0
    }, header)
    self.titleLabel = create("TextLabel", {
        Name = "TitleLabel",
        Size = UDim2.new(1, -60, 0, 24),
        Position = UDim2.new(0, 15, 0, 10),
        BackgroundTransparency = 1,
        Text = self:Translate(self.Title),
        TextColor3 = Theme.TextPrimary,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    }, header)
    self.subtitleLabel = create("TextLabel", {
        Name = "SubtitleLabel",
        Size = UDim2.new(1, -60, 0, 18),
        Position = UDim2.new(0, 15, 0, 32),
        BackgroundTransparency = 1,
        Text = self:Translate(self.SubTitle),
        TextColor3 = Theme.TextSecondary,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    }, header)
    self:OnLanguageChanged(function()
        self.titleLabel.Text = self:Translate(self.Title)
        self.subtitleLabel.Text = self:Translate(self.SubTitle)
    end)
    local closeButton = create("ImageButton", {
        Name = "CloseButton",
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, -35, 0, 18),
        BackgroundTransparency = 1,
        Image = "rbxassetid://9886659276",
        ImageColor3 = Theme.TextPrimary,
        AutoButtonColor = false
    }, header)
    self:_connect(closeButton.MouseButton1Click, function()
        self:SetOpen(false)
    end)
end

function Library:_createDrawer()
    local footer = Metrics.TabBarHeight + 1
    self.drawerFrame = create("Frame", {
        Name = "DrawerSidebar",
        Size = UDim2.new(0, self.drawerWidth, 1, 0),
        Position = self:_drawerPosition(true),
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = self.settings.Transparency,
        BorderSizePixel = 0
    }, self.screenGui)
    self:_createHeader()
    self.headerFrame.BackgroundTransparency = self.settings.Transparency
    self.contentArea = create("Frame", {
        Name = "MainContentArea",
        Size = UDim2.new(1, 0, 1, -(Metrics.HeaderHeight + footer)),
        Position = UDim2.new(0, 0, 0, Metrics.HeaderHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true
    }, self.drawerFrame)
    create("Frame", {
        Name = "Divider",
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -footer),
        BackgroundColor3 = Theme.Line,
        BorderSizePixel = 0
    }, self.drawerFrame)
    self.tabContainer = create("ScrollingFrame", {
        Name = "TabContainer",
        Size = UDim2.new(1, 0, 0, Metrics.TabBarHeight),
        Position = UDim2.new(0, 0, 1, -Metrics.TabBarHeight),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ScrollingDirection = Enum.ScrollingDirection.X,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Line,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        Active = true
    }, self.drawerFrame)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, Metrics.TabGap)
    }, self.tabContainer)
    create("UIPadding", {
        PaddingLeft = UDim.new(0, Metrics.TabBarPadding),
        PaddingRight = UDim.new(0, Metrics.TabBarPadding),
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6)
    }, self.tabContainer)
end

-- // Toggle Button
function Library:_createToggleButton()
    local toggleButton = create("TextButton", {
        Name = "ToggleButton",
        Size = UDim2.new(0, Metrics.ToggleSize, 0, Metrics.ToggleSize),
        Position = UDim2.new(0, 20, 0.5, -Metrics.ToggleSize / 2),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        Visible = false
    }, self.screenGui)
    addCorner(toggleButton, 10)
    addStroke(toggleButton, Theme.Line, 1.5)
    local texture = create("ImageLabel", {
        Name = "Texture",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = "rbxassetid://77526194033506",
        ImageTransparency = 0.3,
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 1
    }, toggleButton)
    addCorner(texture, 10)
    self.toggleButton = toggleButton
    self:_bindToggleDrag(toggleButton)
end

function Library:_bindToggleDrag(toggleButton)
    local isActualDrag = false
    local dragStart = Vector3.zero
    local startPosition = toggleButton.Position
    local moveConnection = nil
    local endConnection = nil
    local stopTracking = function()
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
    self:_connect(toggleButton.InputBegan, function(input)
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
            if delta.Magnitude > Metrics.DragThreshold then
                isActualDrag = true
            end
            if isActualDrag then
                toggleButton.Position = offsetPosition(startPosition, delta)
            end
        end)
        endConnection = UserInputService.InputEnded:Connect(function(endInput)
            if not isPointerInput(endInput) then
                return
            end
            stopTracking()
            if not isActualDrag then
                self:SetOpen(true)
            end
            isActualDrag = false
        end)
    end)
end

-- // Open / Close
function Library:SetOpen(state)
    state = state == true
    if self.destroyed or self.isOpen == state then
        return
    end
    self.isOpen = state
    self.openToken = self.openToken + 1
    local token = self.openToken
    if state then
        self.toggleButton.Visible = false
        self.drawerFrame.Visible = true
        tween(self.drawerFrame, Tweens.Drawer, {
            Position = self:_drawerPosition(true)
        })
        return
    end
    self.toggleButton.Visible = true
    local closing = tween(self.drawerFrame, Tweens.Drawer, {
        Position = self:_drawerPosition(false)
    })
    closing.Completed:Connect(function()
        if token == self.openToken and not self.isOpen and self.drawerFrame then
            self.drawerFrame.Visible = false
        end
    end)
end

function Library:Toggle()
    self:SetOpen(not self.isOpen)
end

function Library:IsOpen()
    return self.isOpen
end

-- // Tabs
function Library:GetTab(nameOrIndex)
    if type(nameOrIndex) == "number" then
        return self.tabs[nameOrIndex]
    end
    for _, tab in ipairs(self.tabs) do
        if tab.name == nameOrIndex then
            return tab
        end
    end
    return nil
end

function Library:_applyTabState(tab, selected, instant)
    local width = selected and Metrics.TabExpanded or Metrics.TabSize
    local size = UDim2.new(0, width, 0, Metrics.TabSize)
    local strokeColor = selected and Theme.LineActive or Theme.Line
    if instant then
        cancelTween(tab.card)
        cancelTween(tab.stroke)
        tab.card.Size = size
        tab.stroke.Color = strokeColor
    else
        tween(tab.card, Tweens.Card, { Size = size })
        tween(tab.stroke, Tweens.Hover, { Color = strokeColor })
    end
    tab.textContainer.Visible = selected
    tab.frame.Visible = selected
    tab.Page.ScrollingEnabled = true
end

function Library:_revealTab(tab)
    local container = self.tabContainer
    local index = table.find(self.tabs, tab)
    if not container or not index then
        return
    end
    local margin = Metrics.TabBarPadding
    local left = margin + (index - 1) * (Metrics.TabSize + Metrics.TabGap)
    local right = left + Metrics.TabExpanded
    local view = container.AbsoluteSize.X
    local current = container.CanvasPosition.X
    local target = current
    if right - target > view - margin then
        target = right - view + margin
    end
    if left - target < margin then
        target = left - margin
    end
    target = math.max(target, 0)
    if math.abs(target - current) < 1 then
        return
    end
    tween(container, Tweens.Card, { CanvasPosition = Vector2.new(target, 0) })
end

function Library:SelectTab(target, instant)
    local tab = target
    if type(target) == "string" or type(target) == "number" then
        tab = self:GetTab(target)
    end
    if type(tab) ~= "table" or tab.window ~= self then
        return false
    end
    if self.selectedTab == tab then
        return true
    end
    local previous = self.selectedTab
    self.selectedTab = tab
    if previous then
        self:_applyTabState(previous, false, instant)
    end
    self:_applyTabState(tab, true, instant)
    if not instant then
        self:_revealTab(tab)
    end
    return true
end

local createEmptyNotice = function(parent, window)
    local notice = create("Frame", {
        Name = "Notice",
        Size = UDim2.new(1, -40, 0, 100),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1
    }, parent)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 8)
    }, notice)
    create("ImageLabel", {
        Name = "WarningIcon",
        Size = UDim2.new(0, 36, 0, 36),
        BackgroundTransparency = 1,
        Image = resolveIcon("alert-circle", "rbxassetid://10709752996"),
        ImageColor3 = Theme.TextSecondary,
        LayoutOrder = 1
    }, notice)
    local warningText = create("TextLabel", {
        Name = "WarningText",
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = window:Translate("Nothing here yet"),
        TextColor3 = Theme.TextSecondary,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = 2
    }, notice)
    window:OnLanguageChanged(function()
        warningText.Text = window:Translate("Nothing here yet")
    end)
    return notice
end

-- // Color Lock
local lockColor = function(object, property, value)
    object[property] = value
    object:GetPropertyChangedSignal(property):Connect(function()
        if object[property] ~= value then
            object[property] = value
        end
    end)
end

function Library:_createTabCard(name, description, iconKey, order)
    local card = create("TextButton", {
        Name = "TabCard",
        Size = UDim2.new(0, Metrics.TabSize, 0, Metrics.TabSize),
        BackgroundColor3 = Theme.Card,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ClipsDescendants = true,
        LayoutOrder = order
    }, self.tabContainer)
    addCorner(card, 8)
    local stroke = addStroke(card, Theme.Line, 1)
    local iconAsset = resolveIcon(iconKey)
    if iconAsset ~= "" then
        local icon = create("ImageLabel", {
            Name = "Icon",
            Size = UDim2.new(0, 22, 0, 22),
            Position = UDim2.new(0, 13, 0.5, -11),
            BackgroundTransparency = 1,
            Image = iconAsset,
            ImageColor3 = Theme.TextPrimary
        }, card)
        lockColor(icon, "ImageColor3", Theme.TextPrimary)
    end
    local textContainer = create("Frame", {
        Name = "TextContainer",
        Size = UDim2.new(0, 110, 1, 0),
        Position = UDim2.new(0, 44, 0, 0),
        BackgroundTransparency = 1,
        Visible = false
    }, card)
    local titleLabel = create("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -5, 0, 18),
        Position = UDim2.new(0, 0, 0, 7),
        BackgroundTransparency = 1,
        Text = self:Translate(name),
        TextColor3 = Theme.TextPrimary,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    }, textContainer)
    local descriptionLabel = create("TextLabel", {
        Name = "Description",
        Size = UDim2.new(1, -5, 0, 18),
        Position = UDim2.new(0, 0, 0, 23),
        BackgroundTransparency = 1,
        Text = self:Translate(description),
        TextColor3 = Theme.TextSecondary,
        TextSize = 9,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextTruncate = Enum.TextTruncate.AtEnd
    }, textContainer)
    lockColor(card, "BackgroundColor3", Theme.Card)
    lockColor(titleLabel, "TextColor3", Theme.TextPrimary)
    lockColor(descriptionLabel, "TextColor3", Theme.TextSecondary)
    self:OnLanguageChanged(function()
        titleLabel.Text = self:Translate(name)
        descriptionLabel.Text = self:Translate(description)
    end)
    return card, stroke, textContainer
end

function Library:_createTabPage(name)
    local frame = create("Frame", {
        Name = name,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false
    }, self.contentArea)
    local page = create("ScrollingFrame", {
        Name = "Page",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = true,
        ScrollingEnabled = true,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Line,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new()
    }, frame)
    create("UIListLayout", {
        Padding = UDim.new(0, Metrics.ElementGap),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, page)
    create("UIPadding", {
        PaddingTop = UDim.new(0, Metrics.PagePadding),
        PaddingBottom = UDim.new(0, Metrics.PagePadding),
        PaddingLeft = UDim.new(0, Metrics.PagePadding),
        PaddingRight = UDim.new(0, Metrics.PagePadding)
    }, page)
    local notice = createEmptyNotice(frame, self)
    local refresh = function()
        local count = 0
        for _, child in ipairs(page:GetChildren()) do
            if child:IsA("GuiObject") then
                count = count + 1
            end
        end
        notice.Visible = count == 0
    end
    self:_connect(page.ChildAdded, refresh)
    self:_connect(page.ChildRemoved, function()
        task.defer(refresh)
    end)
    refresh()
    return frame, page, refresh
end

function Library:CreateTab(options)
    if not isWindow(self) then
        local current = resolveWindow(self)
        if not isWindow(current) then
            report("Error", "API", "Create a window first: MiniLibrary:CreateWindow({ Title = ... })")
            return nil
        end
        return current:CreateTab(options)
    end
    local settings = type(options) == "table" and options or { Name = options }
    local name = tostring(settings.Name or settings.name or settings.Tab or settings.tab or "Tab")
    local description = tostring(settings.Description or settings.description or "")
    local iconKey = settings.Icon or settings.icon
    local settingsTab = self.settingsTab
    local order = settingsTab and #self.tabs or (#self.tabs + 1)
    local card, stroke, textContainer = self:_createTabCard(name, description, iconKey, order)
    local frame, page, refresh = self:_createTabPage(name)
    local tab = {
        name = name,
        window = self,
        card = card,
        stroke = stroke,
        textContainer = textContainer,
        frame = frame,
        Frame = frame,
        Page = page,
        Refresh = refresh,
        sectionCount = 0
    }
    function tab:Select()
        return self.window:SelectTab(self)
    end
    function tab:CreateSection(title)
        return self.window:_createSection(self, title)
    end
    function tab:GetDefaultSection()
        if not self.defaultSection then
            self.defaultSection = self.window:_createSection(self, "")
        end
        return self.defaultSection
    end
    setmetatable(tab, {
        __index = function(_, key)
            if type(key) ~= "string" then
                return nil
            end
            if key == "CreateElement" then
                return function(_, elementName, elementOptions)
                    return tab:GetDefaultSection():CreateElement(elementName, elementOptions)
                end
            end
            local elementName = key:match("^Create(%w+)$")
            if not elementName then
                return nil
            end
            return function(_, elementOptions)
                return tab:GetDefaultSection():CreateElement(elementName, elementOptions)
            end
        end
    })
    if settingsTab then
        table.insert(self.tabs, order, tab)
        settingsTab.card.LayoutOrder = #self.tabs
    else
        self.tabs[order] = tab
    end
    self:_connect(card.MouseButton1Click, function()
        self.config.Tab = name
        self:SelectTab(tab)
    end)
    if not self.selectedTab then
        self:SelectTab(tab, true)
    end
    if self.config.Tab == name and self.selectedTab ~= tab then
        self:SelectTab(tab, true)
    end
    return tab
end

-- // Destroy
function Library:Destroy()
    if self.destroyed then
        return
    end
    pcall(self.SaveConfig, self, true)
    self.destroyed = true
    pcall(self._unloadAll, self)
    if self.toggleCleanup then
        pcall(self.toggleCleanup)
        self.toggleCleanup = nil
    end
    for _, connection in ipairs(self.connections) do
        pcall(connection.Disconnect, connection)
    end
    table.clear(self.connections)
    if self.screenGui then
        pcall(self.screenGui.Destroy, self.screenGui)
        self.screenGui = nil
    end
    local env = getEnv()
    if env.__MiniWindow == self then
        env.__MiniWindow = nil
    end
    if env.MiniWindow == self then
        env.MiniWindow = nil
    end
    if env.Windows == self then
        env.Windows = nil
    end
    if env.Window == self then
        env.Window = nil
    end
end

-- // Export
local exportEnv = getEnv()
exportEnv.MiniLibrary = Library
exportEnv.MiniElements = MiniElements
exportEnv.Elements = MiniElements

return Library