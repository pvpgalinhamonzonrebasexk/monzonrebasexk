--!nocheck
local NOTIF_URL = "https://raw.githubusercontent.com/pvpgalinhamonzonrebasexk/monzonrebasexk/refs/heads/main/Library/Notifications.luau"


local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")

local genv = {}

do
    local ok, env = pcall(getgenv)
    if ok and type(env) == "table" then
        genv = env
    end
end

local function safe_index(container, key)
    local ok, value = pcall(function()
        return container[key]
    end)
    if ok then
        return value
    end
    return nil
end

local function global(name)
    local value = safe_index(genv, name)
    if value == nil then
        value = safe_index(_G, name)
    end
    return value
end

local function executor_function(name)
    local value = global(name)
    if type(value) == "function" then
        return value
    end
    value = safe_index(debug, name)
    if type(value) == "function" then
        return value
    end
    return nil
end

local function try(fn, ...)
    if type(fn) ~= "function" then
        return false, nil
    end
    return pcall(fn, ...)
end

local decompile_fn = executor_function("decompile")
local getscriptbytecode_fn = executor_function("getscriptbytecode")
local getscriptclosure_fn = executor_function("getscriptclosure")
local getconstants_fn = executor_function("getconstants")
local getscripts_fn = executor_function("getscripts")
local getloadedmodules_fn = executor_function("getloadedmodules")
local getnilinstances_fn = executor_function("getnilinstances")
local getinstances_fn = executor_function("getinstances")
local hookfunction_fn = executor_function("hookfunction")
local newcclosure_fn = executor_function("newcclosure")
local restorefunction_fn = executor_function("restorefunction")
local setstackhidden_fn = executor_function("setstackhidden")
local identifyexecutor_fn = executor_function("identifyexecutor")
local writefile_fn = executor_function("writefile")
local readfile_fn = executor_function("readfile")
local isfile_fn = executor_function("isfile")
local isfolder_fn = executor_function("isfolder")
local makefolder_fn = executor_function("makefolder")

local function find_request()
    local direct = global("request")
    if type(direct) == "function" then
        return direct
    end
    local legacy = global("http_request")
    if type(legacy) == "function" then
        return legacy
    end
    local syn = global("syn")
    if type(syn) == "table" then
        local syn_request = safe_index(syn, "request")
        if type(syn_request) == "function" then
            return syn_request
        end
    end
    local http = global("http")
    if type(http) == "table" then
        local http_request = safe_index(http, "request")
        if type(http_request) == "function" then
            return http_request
        end
    end
    return nil
end

local request_fn = find_request()

local function find_native_b64()
    local crypt = global("crypt")
    if type(crypt) == "table" then
        local direct = safe_index(crypt, "base64encode")
        if type(direct) == "function" then
            return direct
        end
        local underscored = safe_index(crypt, "base64_encode")
        if type(underscored) == "function" then
            return underscored
        end
        local nested = safe_index(crypt, "base64")
        if type(nested) == "table" then
            local nested_encode = safe_index(nested, "encode")
            if type(nested_encode) == "function" then
                return nested_encode
            end
        end
    end
    local global_encode = global("base64encode")
    if type(global_encode) == "function" then
        return global_encode
    end
    local global_underscored = global("base64_encode")
    if type(global_underscored) == "function" then
        return global_underscored
    end
    local base64 = global("base64")
    if type(base64) == "table" then
        local base64_encode_fn = safe_index(base64, "encode")
        if type(base64_encode_fn) == "function" then
            return base64_encode_fn
        end
    end
    return nil
end

local native_b64 = find_native_b64()

local B64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_CHARS = {}

for index = 1, 64 do
    B64_CHARS[index] = B64_ALPHABET:sub(index, index)
end

local function manual_b64(data)
    local result = {}
    local length = string.len(data)
    for index = 1, length, 3 do
        local b1 = data:byte(index) or 0
        local b2 = data:byte(index + 1) or 0
        local b3 = data:byte(index + 2) or 0
        local number = b1 * 65536 + b2 * 256 + b3
        result[#result + 1] = B64_CHARS[math.floor(number / 262144) % 64 + 1]
        result[#result + 1] = B64_CHARS[math.floor(number / 4096) % 64 + 1]
        if index + 1 <= length then
            result[#result + 1] = B64_CHARS[math.floor(number / 64) % 64 + 1]
        else
            result[#result + 1] = "="
        end
        if index + 2 <= length then
            result[#result + 1] = B64_CHARS[number % 64 + 1]
        else
            result[#result + 1] = "="
        end
    end
    return table.concat(result)
end

local function base64_encode(data)
    if native_b64 then
        local ok, encoded = pcall(native_b64, data)
        if ok and type(encoded) == "string" and encoded ~= "" then
            return encoded
        end
    end
    return manual_b64(data)
end

local Notifications

do
    local ok, lib = pcall(function()
        return loadstring(game:HttpGet(NOTIF_URL))()
    end)
    if ok and type(lib) == "table" and type(safe_index(lib, "Notify")) == "function" then
        Notifications = lib
        try(safe_index(lib, "SetName"), "bytecore")
        try(safe_index(lib, "SetMaxVisible"), 4)
        try(safe_index(lib, "SetGroup"), false)
        try(safe_index(lib, "SetClickToClose"), true)
    end
end

local DUMMY = {
    Update = function()
    end,
    Close = function()
    end,
    IsClosed = function()
        return true
    end,
}

local function notify(options)
    if Notifications then
        local ok, handle = pcall(Notifications.Notify, options)
        if ok and type(handle) == "table" then
            return handle
        end
        if ok then
            return DUMMY
        end
    end
    print("[bytecore] " .. tostring(options.Title) .. " | " .. tostring(options.Description))
    return DUMMY
end

local function update(handle, options, quiet)
    try(safe_index(handle, "Update"), options)
    if not Notifications and not quiet then
        print("[bytecore] " .. tostring(options.Title) .. " | " .. tostring(options.Description))
    end
end

local lastProgress = 0

local function progress(handle, title, description, force)
    local now = os.clock()
    if not force and now - lastProgress < 0.3 then
        return
    end
    lastProgress = now
    update(handle, {
        Title = title,
        Description = description,
        Duration = 0,
        Type = "Info",
    }, true)
end

local ACCENT_PAIRS = {
    {"á", "a"},
    {"à", "a"},
    {"â", "a"},
    {"ã", "a"},
    {"ä", "a"},
    {"é", "e"},
    {"è", "e"},
    {"ê", "e"},
    {"ë", "e"},
    {"í", "i"},
    {"ì", "i"},
    {"î", "i"},
    {"ï", "i"},
    {"ó", "o"},
    {"ò", "o"},
    {"ô", "o"},
    {"õ", "o"},
    {"ö", "o"},
    {"ú", "u"},
    {"ù", "u"},
    {"û", "u"},
    {"ü", "u"},
    {"ç", "c"},
    {"ñ", "n"},
    {"Á", "A"},
    {"À", "A"},
    {"Â", "A"},
    {"Ã", "A"},
    {"Ä", "A"},
    {"É", "E"},
    {"È", "E"},
    {"Ê", "E"},
    {"Ë", "E"},
    {"Í", "I"},
    {"Ì", "I"},
    {"Î", "I"},
    {"Ï", "I"},
    {"Ó", "O"},
    {"Ò", "O"},
    {"Ô", "O"},
    {"Õ", "O"},
    {"Ö", "O"},
    {"Ú", "U"},
    {"Ù", "U"},
    {"Û", "U"},
    {"Ü", "U"},
    {"Ç", "C"},
    {"Ñ", "N"},
}

local ACCENT_LOOKUP = {}

for _, pair in ipairs(ACCENT_PAIRS) do
    ACCENT_LOOKUP[pair[1]] = pair[2]
end

local function remove_accents(value)
    local result = value:gsub("[\194-\244][\128-\191]*", function(character)
        return ACCENT_LOOKUP[character]
    end)
    return result
end

local function sanitize(value)
    value = tostring(value)
    if value:find("[\128-\255]") then
        value = remove_accents(value)
    end
    value = (value:gsub("[^%w%-%_%. ]", "_"))
    value = value:sub(1, 80)
    value = (value:gsub("[%s%.]+$", ""))
    value = (value:gsub("^[%s%.]+", ""))
    return value
end

local function safe_name(value, limit)
    local name = sanitize(value)
    if limit then
        name = name:sub(1, limit)
    end
    if name == "" or name:match("^%s*$") then
        return "_"
    end
    return name
end

local function get_placeinfo()
    local placeId = game.PlaceId
    local gameName = "game"
    local info
    pcall(function()
        info = MarketplaceService:GetProductInfoAsync(placeId)
    end)
    if type(info) == "table" and info.Name then
        local name = sanitize(info.Name)
        name = (name:gsub("%s+", " "))
        name = name:match("^%s*(.-)%s*$")
        name = name:sub(1, 50)
        if name ~= "" and not name:match("^[%s_]*$") then
            gameName = name
        end
    end
    return placeId, gameName, info
end

local function build_root(gameName, placeId)
    return gameName .. "_" .. tostring(placeId)
end

local function build_path(object)
    local reversed = {}
    local current = object
    while current and current ~= game do
        reversed[#reversed + 1] = safe_name(current.Name)
        current = current.Parent
    end
    if current == nil then
        reversed[#reversed + 1] = "NilInstances"
    end
    local segments = {}
    for index = #reversed, 1, -1 do
        segments[#segments + 1] = reversed[index]
    end
    return table.concat(segments, "/")
end

local function full_name(instance)
    local ok, path = pcall(instance.GetFullName, instance)
    if not ok then
        path = tostring(instance.Name)
    end
    if instance.Parent == nil and instance ~= game then
        path = "[nil] " .. path
    end
    return path
end

local function system_key(instance)
    local chain = {}
    local current = instance
    while current and current ~= game do
        chain[#chain + 1] = current
        current = current.Parent
    end
    if current == nil then
        return "NilInstances"
    end
    local count = #chain
    if count == 0 then
        return "game"
    end
    local service = chain[count]
    local key = safe_name(service.Name)
    if service.ClassName == "Workspace" or service.ClassName == "Players" then
        return key
    end
    local child = chain[count - 1]
    if child then
        key = key .. "/" .. safe_name(child.Name)
    end
    return key
end

local function safe_get(instance, property)
    local ok, value = pcall(function()
        return instance[property]
    end)
    if ok then
        return value
    end
    return nil
end

local function format_value(value)
    local kind = typeof(value)
    if kind == "string" then
        local text = tostring(value)
        if #text > 300 then
            text = text:sub(1, 300) .. "..."
        end
        text = (text:gsub("[\r\n]+", " "))
        return string.format("%q", text)
    end
    if kind == "Instance" then
        local ok, path = pcall(value.GetFullName, value)
        if not ok then
            path = value.Name
        end
        return "<" .. value.ClassName .. " " .. path .. ">"
    end
    return tostring(value)
end

local function format_attributes(instance)
    local ok, attributes = pcall(instance.GetAttributes, instance)
    if not ok or type(attributes) ~= "table" or next(attributes) == nil then
        return ""
    end
    local parts = {}
    for key, value in pairs(attributes) do
        parts[#parts + 1] = tostring(key) .. "=" .. format_value(value)
    end
    table.sort(parts)
    return " {" .. table.concat(parts, ", ") .. "}"
end

local function get_bytecode(script)
    local ok, bytecode = try(getscriptbytecode_fn, script)
    if not ok or type(bytecode) ~= "string" or bytecode == "" then
        return nil
    end
    return bytecode
end

local apiCache = {}
local lastRequest = 0
local apiOk = 0
local apiFail = 0

local API_RETRIES = 3
local API_DELAY = 0.5
local API_RATE_LIMIT_WAIT = 2

local APIS = {
    {
        name = "api_lua_expert",
        url = "https://api.lua.expert/decompile",
        key = "script",
        fields = {"source", "result", "output", "decompiled", "code", "data"},
    },
    {
        name = "api_ferib",
        url = "https://lua-decompiler.ferib.dev/decompile",
        key = "bytecode",
        fields = {"source", "result", "output", "decompiled", "code", "data"},
    },
}

local function is_valid_source(source)
    if type(source) ~= "string" or source == "" then
        return false
    end
    local lower = source:lower()
    if lower:find("^%s*$") then
        return false
    end
    if lower:find("unsupported") and not lower:find("local") then
        return false
    end
    if lower:find("^decompile error") then
        return false
    end
    if lower:find("^error:") then
        return false
    end
    return true
end

local RESPONSE_FIELDS = {
    "source",
    "result",
    "output",
    "decompiled",
    "code",
    "data",
    "script",
    "content",
}

local function find_source(value, depth)
    if type(value) == "string" then
        return value
    end
    if type(value) ~= "table" or depth > 3 then
        return nil
    end
    for _, field in ipairs(RESPONSE_FIELDS) do
        local found = find_source(value[field], depth + 1)
        if found and is_valid_source(found) then
            return found
        end
    end
    return nil
end

local function parse_api_body(api, body)
    local parsedOk, parsed = pcall(HttpService.JSONDecode, HttpService, body)
    if not parsedOk then
        return body
    end
    if type(parsed) ~= "table" then
        return nil
    end
    for _, field in ipairs(api.fields) do
        if type(parsed[field]) == "string" and is_valid_source(parsed[field]) then
            return parsed[field]
        end
    end
    return find_source(parsed, 0)
end

local function api_decompile(bytecode)
    if not request_fn then
        return nil
    end
    local encoded = base64_encode(bytecode)
    if apiCache[encoded] then
        return apiCache[encoded], "api_cache"
    end
    for _, api in ipairs(APIS) do
        for attempt = 1, API_RETRIES do
            local elapsed = os.clock() - lastRequest
            if elapsed < API_DELAY then
                task.wait(API_DELAY - elapsed)
            end
            local ok, response = pcall(request_fn, {
                Url = api.url,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                },
                Body = HttpService:JSONEncode({
                    [api.key] = encoded,
                }),
            })
            lastRequest = os.clock()
            if ok and type(response) == "table" then
                if response.StatusCode == 200 and type(response.Body) == "string" and response.Body ~= "" then
                    local source = parse_api_body(api, response.Body)
                    if is_valid_source(source) then
                        apiCache[encoded] = source
                        apiOk = apiOk + 1
                        return source, api.name
                    end
                    break
                end
                if response.StatusCode == 429 or response.StatusCode == 503 then
                    task.wait(API_RATE_LIMIT_WAIT * attempt)
                else
                    break
                end
            end
        end
    end
    apiFail = apiFail + 1
    return nil
end

local function extract_strings(bytecode)
    local result = {}
    local seen = {}
    for text in bytecode:gmatch("[ -~]+") do
        if #text >= 4 and not seen[text] then
            seen[text] = true
            table.insert(result, text)
        end
    end
    return result
end

local function extract_constants(script)
    local okClosure, closure = try(getscriptclosure_fn, script)
    if not okClosure or type(closure) ~= "function" then
        return nil
    end
    local okConstants, constants = try(getconstants_fn, closure)
    if not okConstants or type(constants) ~= "table" then
        return nil
    end
    local lines = {"-- constants via getconstants"}
    for _, value in ipairs(constants) do
        if type(value) == "string" and #value >= 4 then
            table.insert(lines, value)
        end
    end
    if #lines <= 1 then
        return nil
    end
    return table.concat(lines, "\n"), "constants"
end

local intercepted = {}
local orig_loadstring
local hookMode
local oth = global("oth")

local function hook_callback(source, chunkname)
    if not orig_loadstring then
        return nil, "loadstring unavailable"
    end
    if type(source) == "string" and is_valid_source(source) and #source > 100 then
        local key = sanitize(tostring(chunkname or source:sub(1, 60)))
        if key ~= "" then
            intercepted[key] = source
        end
    end
    return orig_loadstring(source, chunkname)
end

pcall(function()
    if type(oth) == "table" and type(safe_index(oth, "hook")) == "function" then
        orig_loadstring = oth.hook(loadstring, hook_callback)
        hookMode = "oth"
        return
    end
    if type(hookfunction_fn) == "function" then
        local wrapped = hook_callback
        if type(newcclosure_fn) == "function" then
            wrapped = newcclosure_fn(hook_callback)
        end
        orig_loadstring = hookfunction_fn(loadstring, wrapped)
        hookMode = "hookfunction"
    end
end)

local function release_hook()
    if not orig_loadstring then
        return
    end
    if hookMode == "oth" then
        pcall(oth.unhook, loadstring)
        return
    end
    if hookMode == "hookfunction" then
        try(restorefunction_fn, loadstring)
    end
end

local function try_decompile(script, bytecode)
    local version = 0
    if bytecode then
        version = bytecode:byte(1) or 0
    end

    local interceptKey = sanitize(full_name(script))
    if intercepted[interceptKey] then
        return intercepted[interceptKey], "intercepted", version
    end

    for attempt = 1, 2 do
        local okDirect, directSource = try(decompile_fn, script)
        if okDirect and is_valid_source(directSource) then
            return directSource, "local_direct", version
        end
        if attempt < 2 then
            task.wait(0.1)
        end
    end

    local okClosure, closure = try(getscriptclosure_fn, script)
    if okClosure and type(closure) == "function" then
        local okClosureSource, closureSource = try(decompile_fn, closure)
        if okClosureSource and is_valid_source(closureSource) then
            return closureSource, "local_closure", version
        end
    end

    if bytecode then
        local apiSource, apiMethod = api_decompile(bytecode)
        if apiSource then
            return apiSource, apiMethod, version
        end
    end

    local constantsSource, constantsMethod = extract_constants(script)
    if constantsSource then
        return constantsSource, constantsMethod, version
    end

    if bytecode then
        local strings = extract_strings(bytecode)
        if #strings > 0 then
            local lines = {"bytecode v" .. version}
            for _, text in ipairs(strings) do
                table.insert(lines, text)
            end
            return table.concat(lines, "\n"), "strings", version
        end
    end

    return nil, nil, version
end

local function scan_remotes(source)
    local found = {}
    local seen = {}
    local patterns = {
        ":FireServer",
        ":InvokeServer",
        ":FireClient",
        ":FireAllClients",
        ".OnServerEvent",
        ".OnClientEvent",
        ".OnServerInvoke",
        ".OnClientInvoke",
        "RemoteEvent",
        "RemoteFunction",
        "UnreliableRemoteEvent",
    }
    for _, pattern in ipairs(patterns) do
        if source:find(pattern, 1, true) and not seen[pattern] then
            seen[pattern] = true
            table.insert(found, pattern)
        end
    end
    return found
end

local scriptAssets = {}

local function scan_assets(source, path)
    local function add(id)
        local entry = scriptAssets[id]
        if not entry then
            entry = {
                count = 0,
                paths = {},
            }
            scriptAssets[id] = entry
        end
        entry.count = entry.count + 1
        if #entry.paths < 3 and entry.paths[#entry.paths] ~= path then
            table.insert(entry.paths, path)
        end
    end
    for id in source:gmatch("rbxassetid://(%d+)") do
        add(id)
    end
    for id in source:gmatch("asset/%?id=(%d+)") do
        add(id)
    end
end

local KEYWORDS = {
    farm = {
        "farm", "collect", "harvest", "gather", "while true", "task.wait", "gold", "coin", "cash",
        "resource", "ore", "wood", "fish", "crop", "plant", "mine", "chop", "rebirth", "prestige", "xp",
    },
    movement = {
        "walkspeed", "jumppower", "fly", "noclip", "teleport", "tween", "moveto", "cframe", "vehicle", "boost",
    },
    gui = {
        "screengui", "textlabel", "textbutton", "imagelabel", "imagebutton", "scrollingframe",
        "uilistlayout", "uicorner", "notification", "popup",
    },
    network = {
        "remoteevent", "remotefunction", "fireserver", "invokeserver", "fireclient", "fireallclients",
        "onserverevent", "onclientevent", "bindable",
    },
    util = {
        "getservice", "waitforchild", "findfirstchild", "getdescendants", "getchildren", "destroy",
    },
}

local function classify_script(source)
    if not source then
        return {}
    end
    local lower = source:lower()
    local tags = {}
    for category, words in pairs(KEYWORDS) do
        local score = 0
        for _, word in ipairs(words) do
            if lower:find(word, 1, true) then
                score = score + 1
            end
        end
        if score >= 3 then
            table.insert(tags, category)
        end
    end
    table.sort(tags)
    return tags
end

local knownFolders = {}

local function folder_exists(path)
    if knownFolders[path] then
        return true
    end
    local ok, result = try(isfolder_fn, path)
    return ok and result == true
end

local function file_exists(path)
    local ok, result = try(isfile_fn, path)
    return ok and result == true
end

local function ensure_dirs(path)
    local parts = {}
    for part in path:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    local current = ""
    for index = 1, #parts - 1 do
        if current == "" then
            current = parts[index]
        else
            current = current .. "/" .. parts[index]
        end
        if not knownFolders[current] then
            if not folder_exists(current) then
                local ok = try(makefolder_fn, current)
                if not ok then
                    return false
                end
            end
            knownFolders[current] = true
        end
    end
    return true
end

local function resolve_script_directory(root, script, filePath)
    local class = script.ClassName
    local base = root .. "/Scripts/Client"
    if class == "ModuleScript" then
        base = root .. "/Scripts/Modules"
    elseif class == "Script" then
        base = root .. "/Scripts/Server"
    end
    return base .. "/" .. filePath
end

local function leaf_name(filePath)
    local leaf = filePath:match("[^/]+$")
    if leaf then
        return leaf
    end
    return filePath
end

local function write_file(path, content)
    if not ensure_dirs(path) then
        return false
    end
    local ok = try(writefile_fn, path, content)
    return ok
end

local function split_lines(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\r?\n") do
        lines[#lines + 1] = line
    end
    if #lines > 0 and lines[#lines] == "" and text:sub(-1) == "\n" then
        table.remove(lines)
    end
    return lines
end

local function write_lines(base, lines)
    if #lines == 0 then
        return 0
    end
    write_file(base .. ".lua", table.concat(lines, "\n"))
    return 1
end

local function write_systems(directory, entries)
    local groups = {}
    local order = {}
    for _, entry in ipairs(entries) do
        local group = groups[entry.key]
        if not group then
            group = {}
            groups[entry.key] = group
            order[#order + 1] = entry.key
        end
        group[#group + 1] = entry.line
    end
    table.sort(order)
    for _, key in ipairs(order) do
        write_lines(directory .. "/" .. key, groups[key])
    end
    return #order
end

local function boundary_name(line)
    return line:match("^local function ([%w_]+)")
        or line:match("^function ([%w_%.:]+)")
        or line:match("^local ([%w_]+) = function")
        or line:match("^([%w_%.]+) = function")
end

local function opens_block(line)
    local stripped = (line:gsub("%s+$", ""))
    if stripped:match("[%s%)]end$") then
        return false
    end
    return true
end

local function is_block_end(line)
    if line:sub(1, 3) ~= "end" then
        return false
    end
    local following = line:sub(4, 4)
    if following == "" then
        return true
    end
    return not following:match("[%w_]")
end

local function split_source(lines)
    local parts = {}
    local current = {
        from = 1,
        to = 0,
        name = "header",
        isFunction = false,
    }
    local inFunction = false

    local function close_part(upTo)
        if upTo >= current.from then
            current.to = upTo
            parts[#parts + 1] = current
        end
    end

    for index, line in ipairs(lines) do
        local name
        if not inFunction then
            name = boundary_name(line)
        end
        if name then
            close_part(index - 1)
            current = {
                from = index,
                to = 0,
                name = name,
                isFunction = true,
            }
            inFunction = opens_block(line)
        elseif inFunction and is_block_end(line) then
            inFunction = false
            close_part(index)
            current = {
                from = index + 1,
                to = 0,
                name = "main",
                isFunction = false,
            }
        end
    end
    close_part(#lines)
    return parts
end

local function write_script(directory, leaf, source)
    write_file(directory .. "/" .. leaf .. ".lua", source)
    local lines = split_lines(source)
    local parts = split_source(lines)
    local functionCount = 0
    for _, part in ipairs(parts) do
        if part.isFunction then
            functionCount = functionCount + 1
        end
    end
    if functionCount == 0 then
        return 0
    end
    local functionsDirectory = directory .. "/_Functions"
    local index = {leaf .. " | " .. #lines .. " linhas | " .. functionCount .. " funcoes"}
    for number, part in ipairs(parts) do
        local partName = string.format("%04d_%s.lua", number, safe_name(part.name, 50))
        write_file(functionsDirectory .. "/" .. partName, table.concat(lines, "\n", part.from, part.to))
        index[#index + 1] = partName .. " | linhas " .. part.from .. "-" .. part.to
    end
    write_file(functionsDirectory .. "/_index.lua", table.concat(index, "\n"))
    return functionCount
end

local function find_dumped(directory, leaf)
    local path = directory .. "/" .. leaf .. ".lua"
    if file_exists(path) then
        return path
    end
    return nil
end

local SCRIPT_CLASSES = {
    LocalScript = true,
    Script = true,
    ModuleScript = true,
}

local function collect_scripts()
    local seen = {}
    local list = {}

    local function add(items)
        if type(items) ~= "table" then
            return
        end
        for _, instance in ipairs(items) do
            if not seen[instance] and SCRIPT_CLASSES[instance.ClassName] then
                seen[instance] = true
                list[#list + 1] = instance
            end
        end
    end

    local okScripts, scripts = try(getscripts_fn)
    if okScripts then
        add(scripts)
    end
    local okModules, modules = try(getloadedmodules_fn)
    if okModules then
        add(modules)
    end
    local okNil, nilInstances = try(getnilinstances_fn)
    if okNil then
        add(nilInstances)
    end
    return list
end

local function collect_instances()
    local seen = {}
    local list = {}

    local function add(items)
        if type(items) ~= "table" then
            return
        end
        for _, instance in ipairs(items) do
            if not seen[instance] then
                seen[instance] = true
                list[#list + 1] = instance
            end
        end
    end

    local okDescendants, descendants = pcall(function()
        return game:GetDescendants()
    end)
    if okDescendants then
        add(descendants)
    end
    local okAll, all = try(getinstances_fn)
    if okAll then
        add(all)
    end
    local okNil, nilInstances = try(getnilinstances_fn)
    if okNil then
        add(nilInstances)
    end
    return list
end

local ASSET_ORDER = {"Sons", "Animacoes", "Imagens", "Meshes"}

local assets = {
    Sons = {},
    Animacoes = {},
    Imagens = {},
    Meshes = {},
}

local assetCount = {
    Sons = 0,
    Animacoes = 0,
    Imagens = 0,
    Meshes = 0,
}

local ASSET_CLASSES = {
    Sound = {
        category = "Sons",
        props = {"SoundId"},
    },
    Animation = {
        category = "Animacoes",
        props = {"AnimationId"},
    },
    ImageLabel = {
        category = "Imagens",
        props = {"Image"},
    },
    ImageButton = {
        category = "Imagens",
        props = {"Image", "HoverImage", "PressedImage"},
    },
    ImageHandleAdornment = {
        category = "Imagens",
        props = {"Image"},
    },
    Decal = {
        category = "Imagens",
        props = {"Texture"},
    },
    Texture = {
        category = "Imagens",
        props = {"Texture"},
    },
    ParticleEmitter = {
        category = "Imagens",
        props = {"Texture"},
    },
    Beam = {
        category = "Imagens",
        props = {"Texture"},
    },
    Trail = {
        category = "Imagens",
        props = {"Texture"},
    },
    Shirt = {
        category = "Imagens",
        props = {"ShirtTemplate"},
    },
    Pants = {
        category = "Imagens",
        props = {"PantsTemplate"},
    },
    ShirtGraphic = {
        category = "Imagens",
        props = {"Graphic"},
    },
    Tool = {
        category = "Imagens",
        props = {"TextureId"},
    },
    Sky = {
        category = "Imagens",
        props = {
            "SkyboxBk",
            "SkyboxDn",
            "SkyboxFt",
            "SkyboxLf",
            "SkyboxRt",
            "SkyboxUp",
            "SunTextureId",
            "MoonTextureId",
        },
    },
    SurfaceAppearance = {
        category = "Imagens",
        props = {"ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap"},
    },
    MaterialVariant = {
        category = "Imagens",
        props = {"ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap"},
    },
    MeshPart = {
        category = "Meshes",
        props = {"MeshId", "TextureID"},
    },
    SpecialMesh = {
        category = "Meshes",
        props = {"MeshId", "TextureId"},
    },
    CharacterMesh = {
        category = "Meshes",
        props = {"MeshId", "BaseTextureId", "OverlayTextureId"},
    },
    WrapLayer = {
        category = "Meshes",
        props = {"ReferenceMeshId", "CageMeshId"},
    },
}

local ASSET_EXTRA = {
    Sound = function(instance)
        return "Nome=" .. instance.Name .. " Dur=" .. tostring(safe_get(instance, "TimeLength"))
    end,
    Animation = function(instance)
        return "Nome=" .. instance.Name
    end,
}

local function record_asset(category, value, label, path, extra)
    local bucket = assets[category]
    local entry = bucket[value]
    if not entry then
        entry = {
            count = 0,
            paths = {},
            extra = extra,
        }
        bucket[value] = entry
        assetCount[category] = assetCount[category] + 1
    end
    entry.count = entry.count + 1
    if #entry.paths < 3 then
        table.insert(entry.paths, label .. " " .. path)
    end
end

local REMOTE_CLASSES = {
    "RemoteEvent",
    "RemoteFunction",
    "UnreliableRemoteEvent",
    "BindableEvent",
    "BindableFunction",
}

local remotes = {}
local remoteSysEntries = {}

for _, class in ipairs(REMOTE_CLASSES) do
    remotes[class] = {}
end

local VALUE_CLASSES = {
    BoolValue = true,
    IntValue = true,
    NumberValue = true,
    StringValue = true,
    ObjectValue = true,
    Color3Value = true,
    Vector3Value = true,
    CFrameValue = true,
    BrickColorValue = true,
    RayValue = true,
}

local SKIP_KEYWORD_CLASSES = {
    Part = true,
    MeshPart = true,
    UnionOperation = true,
    WedgePart = true,
    CornerWedgePart = true,
    TrussPart = true,
    Attachment = true,
    Weld = true,
    WeldConstraint = true,
    Motor6D = true,
    ManualWeld = true,
    Decal = true,
    Texture = true,
    SpecialMesh = true,
    SurfaceAppearance = true,
}

local KEYWORD_GROUPS = {
    {
        file = "Skins",
        words = {
            "skin", "camo", "wrap", "cosmetic", "sticker", "charm", "finish", "emote", "outfit", "costume", "aura",
        },
    },
    {
        file = "Armas",
        words = {
            "weapon", "gun", "knife", "sword", "rifle", "pistol", "shotgun", "sniper", "melee", "grenade", "ammo",
            "viewmodel", "katana", "blade", "bullet", "projectile", "recoil", "damage",
        },
    },
    {
        file = "Itens",
        words = {
            "item", "inventory", "loadout", "hotbar", "equip", "rarity", "loot", "bait", "fishing", "pet", "egg",
            "mutation", "potion", "totem", "relic", "artifact",
        },
    },
    {
        file = "Loja",
        words = {
            "shop", "store", "market", "crate", "chest", "price", "cost", "currency", "coin", "gem", "cash", "money",
            "purchase", "gamepass", "product", "reward", "bundle", "offer", "trade",
        },
    },
    {
        file = "Mundo",
        words = {
            "map", "zone", "island", "world", "spawn", "npc", "boss", "enemy", "mob", "quest", "mission", "dungeon",
            "raid", "arena", "lobby", "portal", "checkpoint", "teleport",
        },
    },
}

local keywordLines = {}

for _, group in ipairs(KEYWORD_GROUPS) do
    keywordLines[group.file] = {}
end

local valueLines = {}
local toolLines = {}
local classCount = {}

local function record_tool(instance, path)
    local children = {}
    local ok, found = pcall(instance.GetChildren, instance)
    if ok then
        for index, child in ipairs(found) do
            if index > 12 then
                children[#children + 1] = "..."
                break
            end
            children[#children + 1] = child.Name .. "(" .. child.ClassName .. ")"
        end
    end
    toolLines[#toolLines + 1] = {
        key = system_key(instance),
        line = instance.ClassName
            .. " | "
            .. path
            .. " | TextureId="
            .. format_value(safe_get(instance, "TextureId"))
            .. " | ToolTip="
            .. format_value(safe_get(instance, "ToolTip"))
            .. " | filhos=["
            .. table.concat(children, ", ")
            .. "]"
            .. format_attributes(instance),
    }
end

local function process_instance(instance)
    local class = instance.ClassName
    classCount[class] = (classCount[class] or 0) + 1

    local remoteBucket = remotes[class]
    if remoteBucket then
        local path = full_name(instance)
        remoteBucket[#remoteBucket + 1] = path
        remoteSysEntries[#remoteSysEntries + 1] = {
            key = system_key(instance),
            line = class .. " | " .. path,
        }
    end

    local spec = ASSET_CLASSES[class]
    if spec then
        local path
        for _, property in ipairs(spec.props) do
            local value = safe_get(instance, property)
            if type(value) == "string" and value ~= "" then
                path = path or full_name(instance)
                local extraBuilder = ASSET_EXTRA[class]
                local extra
                if extraBuilder then
                    extra = extraBuilder(instance)
                end
                record_asset(spec.category, value, class .. "." .. property, path, extra)
            end
        end
    end

    if VALUE_CLASSES[class] then
        valueLines[#valueLines + 1] = {
            key = system_key(instance),
            line = class
                .. " | "
                .. full_name(instance)
                .. " = "
                .. format_value(safe_get(instance, "Value"))
                .. format_attributes(instance),
        }
    end

    if class == "Tool" or class == "HopperBin" then
        record_tool(instance, full_name(instance))
    end

    if not SKIP_KEYWORD_CLASSES[class] then
        local lowerName = instance.Name:lower()
        local path
        for _, group in ipairs(KEYWORD_GROUPS) do
            local bucket = keywordLines[group.file]
            for _, word in ipairs(group.words) do
                if lowerName:find(word, 1, true) then
                    path = path or full_name(instance)
                    local extra = ""
                    if VALUE_CLASSES[class] then
                        extra = " = " .. format_value(safe_get(instance, "Value"))
                    end
                    bucket[#bucket + 1] = {
                        key = system_key(instance),
                        line = class .. " | " .. path .. extra .. format_attributes(instance),
                    }
                    break
                end
            end
        end
    end
end

local DESCRIBE = {
    TextLabel = "Text",
    TextButton = "Text",
    TextBox = "Text",
    ImageLabel = "Image",
    ImageButton = "Image",
    Sound = "SoundId",
    Animation = "AnimationId",
    MeshPart = "MeshId",
    Decal = "Texture",
    Texture = "Texture",
    Tool = "ToolTip",
}

local function describe(instance)
    local class = instance.ClassName
    local property = DESCRIBE[class]
    if property then
        local value = safe_get(instance, property)
        if value ~= nil and value ~= "" then
            return " = " .. format_value(value)
        end
        return ""
    end
    if VALUE_CLASSES[class] then
        return " = " .. format_value(safe_get(instance, "Value"))
    end
    return ""
end

local function dump_tree(root, maxDepth)
    local lines = {}
    local steps = 0

    local function walk(instance, depth)
        local ok, line = pcall(function()
            return string.rep("  ", depth)
                .. instance.ClassName
                .. " "
                .. instance.Name
                .. describe(instance)
                .. format_attributes(instance)
        end)
        if ok then
            lines[#lines + 1] = line
        end
        steps = steps + 1
        if steps % 1500 == 0 then
            task.wait()
        end
        if depth >= maxDepth then
            return
        end
        local okChildren, children = pcall(instance.GetChildren, instance)
        if okChildren then
            for _, child in ipairs(children) do
                walk(child, depth + 1)
            end
        end
    end

    walk(root, 0)
    return lines
end

local function serialize(root)
    local output = {}
    local visiting = {}

    local function emit(text)
        output[#output + 1] = text
    end

    local function emit_text(text)
        emit(string.format("%q", text))
    end

    local function write_value(value, indent)
        local kind = typeof(value)
        if kind == "string" then
            emit_text(value)
        elseif kind == "number" then
            if value ~= value or value == math.huge or value == -math.huge then
                emit_text(tostring(value))
            else
                emit(tostring(value))
            end
        elseif kind == "boolean" or kind == "nil" then
            emit(tostring(value))
        elseif kind == "table" then
            if visiting[value] then
                emit_text("<ciclo>")
                return
            end
            visiting[value] = true
            emit("{\n")
            for key, item in pairs(value) do
                emit(indent .. "  [")
                write_value(key, indent .. "  ")
                emit("] = ")
                write_value(item, indent .. "  ")
                emit(",\n")
            end
            emit(indent .. "}")
            visiting[value] = nil
        elseif kind == "Instance" then
            emit_text(format_value(value))
        elseif kind == "function" then
            emit_text("<function>")
        else
            emit_text("<" .. kind .. " " .. tostring(value) .. ">")
        end
    end

    write_value(root, "")
    return table.concat(output)
end

local function build_game_info(info, placeId, gameName)
    local lines = {}

    local function add(key, value)
        lines[#lines + 1] = key .. ": " .. tostring(value)
    end

    local function add_safe(key, getter)
        local ok, value = pcall(getter)
        if ok and value ~= nil and value ~= "" then
            add(key, value)
        end
    end

    add("Nome", gameName)
    add("PlaceId", placeId)
    add_safe("GameId", function()
        return game.GameId
    end)
    add_safe("JobId", function()
        return game.JobId
    end)
    add_safe("PlaceVersion", function()
        return game.PlaceVersion
    end)
    add_safe("ServerPrivado", function()
        return game.PrivateServerId ~= ""
    end)
    add_safe("Executor", function()
        local name, version = identifyexecutor_fn()
        return tostring(name) .. " " .. tostring(version or "")
    end)
    if info then
        add_safe("Descricao", function()
            local description = (tostring(info.Description):gsub("%s+", " "))
            return description
        end)
        add_safe("Criado", function()
            return info.Created
        end)
        add_safe("Atualizado", function()
            return info.Updated
        end)
        add_safe("Criador", function()
            return tostring(info.Creator.Name)
                .. " | "
                .. tostring(info.Creator.CreatorType)
                .. " | "
                .. tostring(info.Creator.CreatorTargetId or info.Creator.Id)
        end)
    end
    add_safe("Jogadores", function()
        return #Players:GetPlayers() .. "/" .. Players.MaxPlayers
    end)
    add_safe("LocalPlayer", function()
        local player = Players.LocalPlayer
        return player.Name
            .. " | "
            .. player.DisplayName
            .. " | "
            .. player.UserId
            .. " | AccountAge "
            .. player.AccountAge
    end)
    add_safe("Gravity", function()
        return Workspace.Gravity
    end)
    add_safe("StreamingEnabled", function()
        return Workspace.StreamingEnabled
    end)
    add_safe("FallenPartsDestroyHeight", function()
        return Workspace.FallenPartsDestroyHeight
    end)
    return table.concat(lines, "\n")
end

local function build_players()
    local lines = {}
    for _, player in ipairs(Players:GetPlayers()) do
        pcall(function()
            local team = "-"
            if player.Team then
                team = player.Team.Name
            end
            lines[#lines + 1] = player.Name
                .. " | "
                .. player.DisplayName
                .. " | "
                .. player.UserId
                .. " | "
                .. team
                .. " | "
                .. player.AccountAge
        end)
    end
    return table.concat(lines, "\n")
end

if type(setstackhidden_fn) == "function" then
    pcall(setstackhidden_fn, try_decompile, true)
    pcall(setstackhidden_fn, api_decompile, true)
    pcall(setstackhidden_fn, write_file, true)
    pcall(setstackhidden_fn, hook_callback, true)
end

local placeId, gameName, productInfo = get_placeinfo()
local displayName = gameName
local ROOT = build_root(gameName, placeId)
local isResuming = folder_exists(ROOT)

if not isResuming then
    local ok = try(makefolder_fn, ROOT)
    if ok then
        knownFolders[ROOT] = true
    else
        ROOT = "bytecore_" .. tostring(placeId)
        isResuming = folder_exists(ROOT)
        if not isResuming then
            try(makefolder_fn, ROOT)
        end
    end
end

local startLabel = "Iniciando | "

if isResuming then
    startLabel = "Continuando | "
end

local main = notify({
    Id = "bytecore",
    Title = "bytecore",
    Description = startLabel .. displayName .. " | " .. placeId,
    Duration = 0,
    Type = "Info",
})

local errorLog = {}

local function error_handler(message)
    return tostring(message) .. "\n" .. debug.traceback()
end

local function log_error(where, err)
    errorLog[#errorLog + 1] = "[" .. where .. "] " .. tostring(err)
end

local function guarded(where, fn, ...)
    local ok, err = xpcall(fn, error_handler, ...)
    if not ok then
        log_error(where, err)
    end
    return ok
end

local function stage(name, fn)
    local ok, err = xpcall(fn, error_handler)
    if not ok then
        log_error(name, err)
        local firstLine = tostring(err):match("^[^\n]*")
        print("[bytecore] erro em " .. name .. ": " .. tostring(err))
        notify({
            Title = "bytecore | Erro",
            Description = name .. ": " .. tostring(firstLine),
            Duration = 6,
            Type = "Error",
        })
    end
end

stage("info", function()
    write_file(ROOT .. "/Info/game.lua", build_game_info(productInfo, placeId, displayName))
    local playersText = build_players()
    if playersText ~= "" then
        write_file(ROOT .. "/Info/players.lua", playersText)
    end
end)

local scripts = collect_scripts()

local stats = {
    total = #scripts,
    decompiled = 0,
    api = 0,
    strings = 0,
    empty = 0,
    skipped = 0,
    split = 0,
    versions = {},
    tags = {},
}

local scriptList = {}
local taggedList = {}
local failedList = {}
local remoteLogs = {}
local pathCount = {}

local TEXT_METHODS = {
    strings = true,
    constants = true,
}

local function post_process(fullName, source)
    local tags = classify_script(source)
    if #tags > 0 then
        table.insert(taggedList, table.concat(tags, " | ") .. " | " .. fullName)
        for _, tag in ipairs(tags) do
            stats.tags[tag] = (stats.tags[tag] or 0) + 1
        end
    end
    local calls = scan_remotes(source)
    if #calls > 0 then
        remoteLogs[fullName] = calls
    end
    scan_assets(source, fullName)
end

local function process_script(script)
    local filePath = build_path(script)
    if filePath == "" then
        return
    end

    local occurrence = (pathCount[filePath] or 0) + 1
    pathCount[filePath] = occurrence
    if occurrence > 1 then
        filePath = filePath .. "_" .. occurrence
    end

    local bytecode = get_bytecode(script)
    local version = 0
    if bytecode then
        version = bytecode:byte(1) or 0
    end
    local versionKey = "v" .. version
    local fullName = full_name(script)
    local directory = resolve_script_directory(ROOT, script, filePath)
    local leaf = leaf_name(filePath)

    stats.versions[versionKey] = (stats.versions[versionKey] or 0) + 1
    table.insert(scriptList, "[" .. versionKey .. "] " .. script.ClassName .. " " .. fullName)

    if isResuming then
        local existing = find_dumped(directory, leaf)
        if existing then
            stats.skipped = stats.skipped + 1
            local ok, content = try(readfile_fn, existing)
            if ok and type(content) == "string" then
                post_process(fullName, content)
            end
            return
        end
    end

    local source, method = try_decompile(script, bytecode)

    if not source then
        stats.empty = stats.empty + 1
        failedList[#failedList + 1] = "none | " .. fullName
        return
    end

    local methodName = tostring(method)
    local isText = TEXT_METHODS[methodName] == true
    local isApi = methodName:find("api") ~= nil

    if isText then
        write_file(directory .. "/" .. leaf .. ".lua", source)
        failedList[#failedList + 1] = methodName .. " | " .. fullName
    else
        local functionCount = write_script(directory, leaf, source)
        if functionCount > 0 then
            stats.split = stats.split + 1
        end
    end
    post_process(fullName, source)

    if isText then
        stats.strings = stats.strings + 1
    elseif isApi then
        stats.api = stats.api + 1
        stats.decompiled = stats.decompiled + 1
    else
        stats.decompiled = stats.decompiled + 1
    end
end

stage("scripts", function()
    for index, script in ipairs(scripts) do
        guarded("script " .. index, process_script, script)
        progress(
            main,
            "bytecore | Scripts",
            index .. "/" .. #scripts .. " | API: " .. stats.api .. " | Vazios: " .. stats.empty
        )
        if index % 25 == 0 then
            task.wait()
        end
    end
end)

stage("intercepted", function()
    for name, source in pairs(intercepted) do
        guarded("intercepted " .. name, function()
            local leaf = safe_name(name, 80)
            write_script(ROOT .. "/Intercepted/" .. leaf, leaf, source)
        end)
    end
    release_hook()
end)

write_lines(ROOT .. "/Info/scripts", scriptList)
write_lines(ROOT .. "/Info/tagged", taggedList)
write_lines(ROOT .. "/Info/failed", failedList)

local skippedMessage = ""

if stats.skipped > 0 then
    skippedMessage = " | Pulados: " .. stats.skipped
end

local splitMessage = ""

if stats.split > 0 then
    splitMessage = " | Divididos: " .. stats.split
end

notify({
    Title = "bytecore | Scripts",
    Description = "Decompilados: "
        .. stats.decompiled
        .. " | API: "
        .. stats.api
        .. " | Strings: "
        .. stats.strings
        .. " | Vazios: "
        .. stats.empty
        .. skippedMessage
        .. splitMessage,
    Duration = 6,
    Type = "Success",
})

stage("instancias", function()
    local instances = collect_instances()
    local total = #instances
    for index, instance in ipairs(instances) do
        guarded("instancia " .. index, process_instance, instance)
        if index % 2500 == 0 then
            task.wait()
            progress(main, "bytecore | Instancias", index .. "/" .. total)
        end
    end
end)

local function dump_system_tree(name, root, depth)
    local base = ROOT .. "/Tree/" .. name
    local okChildren, children = pcall(root.GetChildren, root)
    if okChildren and #children > 1 then
        local index = {root.ClassName .. " " .. root.Name .. " (" .. #children .. ")"}
        local used = {}
        for _, child in ipairs(children) do
            index[#index + 1] = "  " .. child.ClassName .. " " .. child.Name
            guarded("tree " .. name, function()
                local lines = dump_tree(child, depth - 1)
                local fileName = safe_name(child.Name, 60)
                used[fileName] = (used[fileName] or 0) + 1
                if used[fileName] > 1 then
                    fileName = fileName .. "_" .. used[fileName]
                end
                write_lines(base .. "/" .. fileName, lines)
            end)
        end
        write_lines(base .. "/_root", index)
        return
    end
    write_lines(base, dump_tree(root, depth))
end

stage("arvores", function()
    local trees = {
        {name = "ReplicatedStorage", depth = 12},
        {name = "ReplicatedFirst", depth = 8},
        {name = "StarterGui", depth = 10},
        {name = "StarterPack", depth = 8},
        {name = "StarterPlayer", depth = 8},
        {name = "Lighting", depth = 4},
        {name = "SoundService", depth = 4},
        {name = "MaterialService", depth = 4},
        {name = "Teams", depth = 3},
        {name = "Workspace", depth = 3},
    }
    for _, entry in ipairs(trees) do
        guarded("arvore " .. entry.name, function()
            local service = game:GetService(entry.name)
            progress(main, "bytecore | Arvores", entry.name, true)
            dump_system_tree(entry.name, service, entry.depth)
        end)
    end
    local player = Players.LocalPlayer
    if player then
        local locals = {
            {name = "PlayerGui", root = player:FindFirstChildOfClass("PlayerGui"), depth = 10},
            {name = "Backpack", root = player:FindFirstChildOfClass("Backpack"), depth = 6},
            {name = "Character", root = player.Character, depth = 5},
        }
        for _, entry in ipairs(locals) do
            local root = entry.root
            if root then
                guarded("arvore " .. entry.name, function()
                    progress(main, "bytecore | Arvores", entry.name, true)
                    dump_system_tree(entry.name, root, entry.depth)
                end)
            end
        end
    end
end)

local dataCount = 0

local function write_data(filePath, data)
    local ok, text = pcall(serialize, data)
    if not ok or type(text) ~= "string" or text == "" then
        return false
    end
    return write_file(ROOT .. "/Data/" .. filePath .. ".lua", "return " .. text)
end

stage("dados", function()
    local ok, modules = try(getloadedmodules_fn)
    if not ok or type(modules) ~= "table" then
        return
    end
    local dataPaths = {}
    for index, module in ipairs(modules) do
        guarded("dados " .. index, function()
            local requireOk, returned = pcall(require, module)
            if not requireOk or type(returned) ~= "table" or next(returned) == nil then
                return
            end
            local filePath = build_path(module)
            local occurrence = (dataPaths[filePath] or 0) + 1
            dataPaths[filePath] = occurrence
            if occurrence > 1 then
                filePath = filePath .. "_" .. occurrence
            end
            if write_data(filePath, returned) then
                dataCount = dataCount + 1
            end
        end)
        if index % 20 == 0 then
            task.wait()
            progress(main, "bytecore | Dados", index .. "/" .. #modules .. " | Salvos: " .. dataCount)
        end
    end
end)

local totalRemotes = 0

stage("saida", function()
    local allRemoteLines = {}
    for _, class in ipairs(REMOTE_CLASSES) do
        local paths = remotes[class]
        if #paths > 0 then
            table.sort(paths)
            totalRemotes = totalRemotes + #paths
            local lines = {class .. " (" .. #paths .. ")"}
            for _, path in ipairs(paths) do
                table.insert(lines, "  " .. path)
            end
            write_lines(ROOT .. "/Remotes/" .. class, lines)
            for _, line in ipairs(lines) do
                allRemoteLines[#allRemoteLines + 1] = line
            end
            allRemoteLines[#allRemoteLines + 1] = ""
        end
    end
    write_lines(ROOT .. "/Remotes/todos", allRemoteLines)
    write_systems(ROOT .. "/Remotes/Sistemas", remoteSysEntries)

    if next(remoteLogs) then
        local lines = {"chamadas de remotes detectadas", ""}
        for path, calls in pairs(remoteLogs) do
            table.insert(lines, path)
            for _, call in ipairs(calls) do
                table.insert(lines, "  " .. call)
            end
        end
        write_lines(ROOT .. "/Remotes/calls", lines)
    end

    local everything = {}
    for _, category in ipairs(ASSET_ORDER) do
        local keys = {}
        for value in pairs(assets[category]) do
            keys[#keys + 1] = value
        end
        table.sort(keys)
        if #keys > 0 then
            local lines = {category .. " (" .. #keys .. ")"}
            for _, value in ipairs(keys) do
                local entry = assets[category][value]
                local line = value .. " | x" .. entry.count
                if entry.extra and entry.extra ~= "" then
                    line = line .. " | " .. entry.extra
                end
                line = line .. " | " .. table.concat(entry.paths, " ; ")
                lines[#lines + 1] = line
                everything[#everything + 1] = category .. " | " .. value
            end
            write_lines(ROOT .. "/Assets/" .. category, lines)
        end
    end

    local scriptAssetIds = {}
    for id in pairs(scriptAssets) do
        scriptAssetIds[#scriptAssetIds + 1] = id
    end
    table.sort(scriptAssetIds)
    if #scriptAssetIds > 0 then
        local lines = {"FromScripts (" .. #scriptAssetIds .. ")"}
        for _, id in ipairs(scriptAssetIds) do
            local entry = scriptAssets[id]
            lines[#lines + 1] = "rbxassetid://"
                .. id
                .. " | x"
                .. entry.count
                .. " | "
                .. table.concat(entry.paths, " ; ")
            everything[#everything + 1] = "Script | rbxassetid://" .. id
        end
        write_lines(ROOT .. "/Assets/FromScripts", lines)
    end
    write_lines(ROOT .. "/Assets/todos", everything)

    for _, group in ipairs(KEYWORD_GROUPS) do
        write_systems(ROOT .. "/Search/" .. group.file, keywordLines[group.file])
    end
    write_systems(ROOT .. "/Search/Tools", toolLines)
    write_systems(ROOT .. "/Search/Values", valueLines)

    local ranking = {}
    for class, count in pairs(classCount) do
        ranking[#ranking + 1] = {
            class = class,
            count = count,
        }
    end
    table.sort(ranking, function(a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end
        return a.class < b.class
    end)
    local classLines = {}
    for _, item in ipairs(ranking) do
        classLines[#classLines + 1] = item.class .. " " .. item.count
    end
    write_lines(ROOT .. "/Info/Classes", classLines)
end)

local assetTotal = 0

for _ in pairs(scriptAssets) do
    assetTotal = assetTotal + 1
end

for _, category in ipairs(ASSET_ORDER) do
    assetTotal = assetTotal + assetCount[category]
end

notify({
    Title = "bytecore | Remotes",
    Description = "Total: " .. totalRemotes .. " | API ok: " .. apiOk .. " | Falhas: " .. apiFail,
    Duration = 5,
    Type = "Info",
})

notify({
    Title = "bytecore | Assets",
    Description = "Sons: "
        .. assetCount.Sons
        .. " | Animacoes: "
        .. assetCount.Animacoes
        .. " | Imagens: "
        .. assetCount.Imagens
        .. " | Meshes: "
        .. assetCount.Meshes
        .. " | Dados: "
        .. dataCount,
    Duration = 6,
    Type = "Info",
})

local dominant = "nenhum"
local maxCount = 0

for version, count in pairs(stats.versions) do
    if count > maxCount then
        maxCount = count
        dominant = version
    end
end

write_lines(ROOT .. "/Info/errors", errorLog)

local summary = {
    "Jogo: " .. displayName,
    "PlaceId: " .. tostring(placeId),
    "Scripts: " .. stats.total,
    "Decompilados: " .. stats.decompiled,
    "Via API: " .. stats.api,
    "Strings e constantes: " .. stats.strings,
    "Vazios: " .. stats.empty,
    "Pulados: " .. stats.skipped,
    "Divididos por funcao: " .. stats.split,
    "Remotes: " .. totalRemotes,
    "Assets: " .. assetTotal,
    "Modulos de dados: " .. dataCount,
    "Erros: " .. #errorLog,
    "Versao dominante: " .. dominant,
}

write_file(ROOT .. "/Info/summary.lua", table.concat(summary, "\n"))

local readme = {
    "Scripts/Client: LocalScripts, uma pasta por script com o script completo e _Functions com um arquivo por funcao",
    "Scripts/Server: Scripts",
    "Scripts/Modules: ModuleScripts",
    "Data: tabelas retornadas pelos modulos",
    "Remotes: remotes por classe e por sistema",
    "Assets: sons, animacoes, imagens, meshes e ids vindos de scripts",
    "Tree: arvores dos servicos e do jogador local",
    "Search: skins, armas, itens, loja, mundo, tools e values",
    "Intercepted: codigo capturado via loadstring",
    "Info: game, players, scripts, tagged, failed, errors, summary, classes",
}

write_file(ROOT .. "/README.lua", table.concat(readme, "\n"))

task.wait(1)

update(main, {
    Title = "bytecore | Finalizado",
    Description = displayName .. " | " .. placeId .. " | Versao: " .. dominant .. " | Assets: " .. assetTotal,
    Duration = 8,
    Type = "Success",
})