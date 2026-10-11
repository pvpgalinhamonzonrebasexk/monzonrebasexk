--!nocheck
local NOTIF_URL = "https://raw.githubusercontent.com/pvpgalinhamonzonrebasexk/monzonrebasexk/refs/heads/main/Library/Notifications.luau"

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

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
    {"á", "a"}, {"à", "a"}, {"â", "a"}, {"ã", "a"}, {"ä", "a"},
    {"é", "e"}, {"è", "e"}, {"ê", "e"}, {"ë", "e"},
    {"í", "i"}, {"ì", "i"}, {"î", "i"}, {"ï", "i"},
    {"ó", "o"}, {"ò", "o"}, {"ô", "o"}, {"õ", "o"}, {"ö", "o"},
    {"ú", "u"}, {"ù", "u"}, {"û", "u"}, {"ü", "u"},
    {"ç", "c"}, {"ñ", "n"},
    {"Á", "A"}, {"À", "A"}, {"Â", "A"}, {"Ã", "A"}, {"Ä", "A"},
    {"É", "E"}, {"È", "E"}, {"Ê", "E"}, {"Ë", "E"},
    {"Í", "I"}, {"Ì", "I"}, {"Î", "I"}, {"Ï", "I"},
    {"Ó", "O"}, {"Ò", "O"}, {"Ô", "O"}, {"Õ", "O"}, {"Ö", "O"},
    {"Ú", "U"}, {"Ù", "U"}, {"Û", "U"}, {"Ü", "U"},
    {"Ç", "C"}, {"Ñ", "N"},
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
local API_DELAY = 0.15
local API_RATE_LIMIT_WAIT = 2
local API_URL = "https://api.lua.expert/decompile"

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

local function api_decompile(bytecode)
    if not request_fn then
        return nil
    end
    local encoded = base64_encode(bytecode)
    if apiCache[encoded] then
        return apiCache[encoded], "api_cache"
    end
    for attempt = 1, API_RETRIES do
        local elapsed = os.clock() - lastRequest
        if elapsed < API_DELAY then
            task.wait(API_DELAY - elapsed)
        end
        local ok, response = pcall(request_fn, {
            Url = API_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
            },
            Body = HttpService:JSONEncode({
                script = encoded,
            }),
        })
        lastRequest = os.clock()
        if ok and type(response) == "table" then
            if response.StatusCode == 200 and type(response.Body) == "string" then
                if is_valid_source(response.Body) then
                    apiCache[encoded] = response.Body
                    apiOk = apiOk + 1
                    return response.Body, "api_lua_expert"
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

local function try_decompile(script, bytecode)
    for attempt = 1, 2 do
        local okDirect, directSource = try(decompile_fn, script)
        if okDirect and is_valid_source(directSource) then
            return directSource, "local_direct"
        end
        if attempt < 2 then
            task.wait(0.1)
        end
    end

    local okClosure, closure = try(getscriptclosure_fn, script)
    if okClosure and type(closure) == "function" then
        local okClosureSource, closureSource = try(decompile_fn, closure)
        if okClosureSource and is_valid_source(closureSource) then
            return closureSource, "local_closure"
        end
    end

    if bytecode then
        local apiSource, apiMethod = api_decompile(bytecode)
        if apiSource then
            return apiSource, apiMethod
        end
    end

    local constantsSource, constantsMethod = extract_constants(script)
    if constantsSource then
        return constantsSource, constantsMethod
    end

    if bytecode then
        local strings = extract_strings(bytecode)
        if #strings > 0 then
            local lines = {"bytecode v" .. (bytecode:byte(1) or 0)}
            for _, text in ipairs(strings) do
                table.insert(lines, text)
            end
            return table.concat(lines, "\n"), "strings"
        end
    end

    return nil, nil
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

local function write_file(path, content)
    if not ensure_dirs(path) then
        return false
    end
    local ok = try(writefile_fn, path, content)
    return ok
end

local function write_lines(base, lines)
    if #lines == 0 then
        return
    end
    write_file(base .. ".lua", table.concat(lines, "\n"))
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

local function write_script(directory, leaf, source, lines)
    write_file(directory .. "/" .. leaf .. ".lua", source)
    local parts = split_source(lines)
    local functionNames = {}
    for _, part in ipairs(parts) do
        if part.isFunction then
            functionNames[#functionNames + 1] = part.name .. " | linhas " .. part.from .. "-" .. part.to
        end
    end
    local functionCount = #functionNames
    if functionCount == 0 then
        return 0, functionNames
    end
    local functionsDirectory = directory .. "/_Functions"
    local index = {leaf .. " | " .. #lines .. " linhas | " .. functionCount .. " funcoes"}
    for number, part in ipairs(parts) do
        local partName = string.format("%04d_%s.lua", number, safe_name(part.name, 50))
        write_file(functionsDirectory .. "/" .. partName, table.concat(lines, "\n", part.from, part.to))
        index[#index + 1] = partName .. " | linhas " .. part.from .. "-" .. part.to
    end
    write_file(functionsDirectory .. "/_index.lua", table.concat(index, "\n"))
    return functionCount, functionNames
end

local REMOTE_PATTERNS = {
    ":FireServer",
    ":InvokeServer",
    ":FireClient",
    ":FireAllClients",
    ":InvokeClient",
    ".OnServerEvent",
    ".OnClientEvent",
    ".OnServerInvoke",
    ".OnClientInvoke",
}

local REQUIRE_PATTERNS = {
    "require(",
    "require (",
}

local function find_matches(lines, patterns, limit)
    local found = {}
    for number, line in ipairs(lines) do
        for _, pattern in ipairs(patterns) do
            if line:find(pattern, 1, true) then
                local text = line:match("^%s*(.-)%s*$")
                if #text > 160 then
                    text = text:sub(1, 160) .. "..."
                end
                found[#found + 1] = "  linha " .. number .. ": " .. text
                break
            end
        end
        if #found >= limit then
            break
        end
    end
    return found
end

local function read_property(instance, property)
    local ok, value = pcall(function()
        return instance[property]
    end)
    if ok and value ~= nil then
        return tostring(value)
    end
    return nil
end

local function format_attributes(instance)
    local ok, attributes = pcall(instance.GetAttributes, instance)
    if not ok or type(attributes) ~= "table" then
        return {}
    end
    local parts = {}
    for key, value in pairs(attributes) do
        parts[#parts + 1] = "  " .. tostring(key) .. " = " .. tostring(value)
    end
    table.sort(parts)
    return parts
end

local function write_info(directory, script, fullName, bytecode, method, source, lines, functionNames)
    local info = {}

    local function add(key, value)
        if value ~= nil and value ~= "" then
            info[#info + 1] = key .. ": " .. tostring(value)
        end
    end

    local function add_section(title, items)
        if #items == 0 then
            return
        end
        info[#info + 1] = ""
        info[#info + 1] = title .. " (" .. #items .. ")"
        for _, item in ipairs(items) do
            info[#info + 1] = item
        end
    end

    local parent = script.Parent
    local parentText
    if parent then
        parentText = tostring(parent.ClassName) .. " " .. full_name(parent)
    else
        parentText = "nil"
    end

    add("Nome", script.Name)
    add("Classe", script.ClassName)
    add("Caminho", fullName)
    add("Pai", parentText)
    add("Metodo", method or "nenhum")
    add("Enabled", read_property(script, "Enabled"))
    add("Disabled", read_property(script, "Disabled"))
    add("RunContext", read_property(script, "RunContext"))
    add("LinkedSource", read_property(script, "LinkedSource"))
    add("ScriptGuid", read_property(script, "ScriptGuid"))
    if bytecode then
        add("BytecodeVersao", bytecode:byte(1) or 0)
        add("BytecodeBytes", #bytecode)
    end
    if source then
        add("Linhas", #lines)
        add("Caracteres", #source)
        add("Funcoes", #functionNames)
    end

    add_section("Atributos", format_attributes(script))
    add_section("Funcoes", functionNames)
    if source then
        add_section("Remotes usados", find_matches(lines, REMOTE_PATTERNS, 80))
        add_section("Requires", find_matches(lines, REQUIRE_PATTERNS, 80))
    end

    write_file(directory .. "/_info.lua", table.concat(info, "\n"))
end

local function find_dumped(directory, leaf)
    return file_exists(directory .. "/" .. leaf .. ".lua")
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

local REMOTE_CLASSES = {
    "RemoteEvent",
    "RemoteFunction",
    "UnreliableRemoteEvent",
    "BindableEvent",
    "BindableFunction",
}

local remotes = {}

for _, class in ipairs(REMOTE_CLASSES) do
    remotes[class] = {}
end

local function process_instance(instance)
    local ok, class = pcall(function()
        return instance.ClassName
    end)
    if not ok then
        return
    end
    local bucket = remotes[class]
    if bucket then
        bucket[#bucket + 1] = full_name(instance)
    end
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
            emit_text("<" .. value.ClassName .. " " .. full_name(value) .. ">")
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
    add_safe("Executor", function()
        local name, version = identifyexecutor_fn()
        return tostring(name) .. " " .. tostring(version or "")
    end)
    if info then
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

local placeId, gameName, productInfo = get_placeinfo()
local ROOT = gameName .. "_" .. tostring(placeId)
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
    Description = startLabel .. gameName .. " | " .. placeId,
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
    write_file(ROOT .. "/Info/game.lua", build_game_info(productInfo, placeId, gameName))
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
}

local scriptList = {}
local failedList = {}
local pathCount = {}

local TEXT_METHODS = {
    strings = true,
    constants = true,
}

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

    if isResuming and find_dumped(directory, leaf) then
        stats.skipped = stats.skipped + 1
        return
    end

    local source, method = try_decompile(script, bytecode)

    if not source then
        stats.empty = stats.empty + 1
        failedList[#failedList + 1] = "none | " .. fullName
        write_info(directory, script, fullName, bytecode, nil, nil, {}, {})
        return
    end

    local methodName = tostring(method)
    local isText = TEXT_METHODS[methodName] == true
    local isApi = methodName:find("api") ~= nil
    local lines = split_lines(source)

    if isText then
        write_file(directory .. "/" .. leaf .. ".lua", source)
        write_info(directory, script, fullName, bytecode, methodName, source, lines, {})
        failedList[#failedList + 1] = methodName .. " | " .. fullName
        stats.strings = stats.strings + 1
        return
    end

    local functionCount, functionNames = write_script(directory, leaf, source, lines)
    write_info(directory, script, fullName, bytecode, methodName, source, lines, functionNames)
    if functionCount > 0 then
        stats.split = stats.split + 1
    end
    stats.decompiled = stats.decompiled + 1
    if isApi then
        stats.api = stats.api + 1
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

write_lines(ROOT .. "/Info/scripts", scriptList)
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

stage("remotes", function()
    local instances = collect_instances()
    local total = #instances
    for index, instance in ipairs(instances) do
        guarded("instancia " .. index, process_instance, instance)
        if index % 2500 == 0 then
            task.wait()
            progress(main, "bytecore | Remotes", index .. "/" .. total)
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
        end
    end
end)

notify({
    Title = "bytecore | Remotes",
    Description = "Total: " .. totalRemotes .. " | Dados: " .. dataCount .. " | API ok: " .. apiOk .. " | Falhas: " .. apiFail,
    Duration = 5,
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

write_file(ROOT .. "/Info/summary.lua", table.concat({
    "Jogo: " .. gameName,
    "PlaceId: " .. tostring(placeId),
    "Scripts: " .. stats.total,
    "Decompilados: " .. stats.decompiled,
    "Via API: " .. stats.api,
    "Strings e constantes: " .. stats.strings,
    "Vazios: " .. stats.empty,
    "Pulados: " .. stats.skipped,
    "Divididos por funcao: " .. stats.split,
    "Remotes: " .. totalRemotes,
    "Modulos de dados: " .. dataCount,
    "Erros: " .. #errorLog,
    "Versao dominante: " .. dominant,
}, "\n"))

task.wait(1)

update(main, {
    Title = "bytecore | Finalizado",
    Description = gameName .. " | " .. placeId .. " | Versao: " .. dominant .. " | Dados: " .. dataCount,
    Duration = 8,
    Type = "Success",
})