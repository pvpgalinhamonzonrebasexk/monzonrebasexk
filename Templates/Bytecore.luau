local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local env = (getgenv and getgenv()) or shared
local rawWarn = warn

local NOTIFICATIONS_URL = "https://raw.githubusercontent.com/pvpgalinhamonzonrebasexk/monzonrebasexk/refs/heads/main/Library/Notifications.luau"
local DECOMPILE_TIMEOUT = 15
local API_INTERVAL = 0.8
local YIELD_EVERY = 25
local SENV_LIMIT = 20

local httpRequest = request or http_request or (syn and syn.request) or (http and http.request)

local function fallback(kind, title, description)
	local text = tostring(description)
	pcall(rawWarn, "[bytecore " .. tostring(kind) .. "] " .. tostring(title) .. ": " .. text)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = tostring(title),
			Text = string.sub(text, 1, 250),
			Duration = 8,
		})
	end)
end

local Notifications = env.BytecoreNotifications
local notificationsError = nil

if not Notifications then
	local libs = rawget(env, "Librarys")
	if type(libs) == "table" and type(libs.Notifications) == "table" and libs.Notifications.Notify then
		Notifications = libs.Notifications
	else
		local ok, result = pcall(function()
			return loadstring(game:HttpGet(NOTIFICATIONS_URL))()
		end)
		if ok and type(result) == "table" and result.Notify then
			Notifications = result
		else
			notificationsError = ok and "Module did not return a table with Notify." or result
		end
	end
	env.BytecoreNotifications = Notifications
end

local notifyAt = {}
local notifyFailedAt = 0

local function notify(kind, title, description, id, duration, cooldown)
	if id and cooldown then
		local now = os.clock()
		local last = notifyAt[id]
		if last and now - last < cooldown then
			return
		end
		notifyAt[id] = now
	end
	local important = kind == "Error" or kind == "Warning"
	if not Notifications then
		if important then
			fallback(kind, title, description)
		end
		return
	end
	local ok, err = pcall(Notifications.Notify, {
		Title = title,
		Description = description,
		Duration = duration or (kind == "Error" and 6 or 4),
		Type = kind,
		Id = id,
	})
	if ok then
		return
	end
	local now = os.clock()
	if now - notifyFailedAt > 5 then
		notifyFailedAt = now
		fallback("Error", "Notification failed", err)
	end
	if important then
		fallback(kind, title, description)
	end
end

if notificationsError then
	fallback("Error", "Notifications", "Failed to load the module: " .. tostring(notificationsError))
end

local function Notify(options)
	notify(options.Type or "Info", options.Title, options.Description, options.Id, options.Duration)
end

local function fail(title, err, id, cooldown)
	local message = tostring(err)
	if #message > 220 then
		message = string.sub(message, 1, 220) .. "..."
	end
	notify("Error", title, message, id or ("error_" .. title), 8, cooldown or 3)
end

local function joinArguments(...)
	local parts = table.pack(...)
	for i = 1, parts.n do
		parts[i] = tostring(parts[i])
	end
	return table.concat(parts, " ", 1, parts.n)
end

local function print(...)
	notify("Info", "bytecore", joinArguments(...), "print", 5)
end

local function warn(...)
	notify("Warning", "bytecore", joinArguments(...), "warn", 6)
end

local accentMap = {
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

local function remove_accents(s)
	for _, pair in ipairs(accentMap) do
		s = s:gsub(pair[1], pair[2])
	end
	return s
end

local function clean_name(s)
	local name = remove_accents(tostring(s)):gsub("[^%w%-_%. ]", "_")
	name = name:gsub("%s+", " ")
	name = name:match("^%s*(.-)%s*$")
	name = name:gsub("^%.+", "_")
	return name:sub(1, 50)
end

local function get_product_name(placeId)
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(placeId)
	end)
	if not ok or type(info) ~= "table" then
		ok, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(placeId)
		end)
	end
	if ok and type(info) == "table" and type(info.Name) == "string" then
		return info.Name
	end
	return nil
end

local function get_placeinfo()
	local placeId = game.PlaceId
	local gameName = "game"
	local productName = get_product_name(placeId)
	if productName then
		local cleaned = clean_name(productName)
		if cleaned ~= "" and not cleaned:match("^[%s_]*$") then
			gameName = cleaned
		end
	end
	return placeId, gameName
end

local function sanitize(s)
	local name = tostring(s):gsub("[^%w%-_%. ]", "_")
	name = name:sub(1, 80)
	name = name:gsub("[%s%.]+$", "")
	if name == "" or name:match("^%.+$") then
		name = "_"
	end
	return name
end

local function build_path(obj)
	local parts = {}
	local current = obj
	local depth = 0
	while current and current ~= game and depth < 64 do
		table.insert(parts, 1, sanitize(current.Name))
		current = current.Parent
		depth += 1
	end
	return table.concat(parts, "/")
end

local function get_extension(script)
	if script.ClassName == "LocalScript" then
		return ".client.lua"
	end
	if script.ClassName == "ModuleScript" then
		return ".lua"
	end
	return ".server.lua"
end

local function get_bytecode(script)
	local ok, bc = pcall(getscriptbytecode, script)
	if not ok or type(bc) ~= "string" or bc == "" then
		return nil
	end
	return bc
end

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function sextet(n, divisor)
	local index = math.floor(n / divisor) % 64 + 1
	return b64chars:sub(index, index)
end

local function manual_base64(data)
	local result = {}
	local len = #data
	for idx = 1, len, 3 do
		local b1, b2, b3 = data:byte(idx, idx + 2)
		local n = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)
		result[#result + 1] = sextet(n, 262144)
		result[#result + 1] = sextet(n, 4096)
		result[#result + 1] = b2 and sextet(n, 64) or "="
		result[#result + 1] = b3 and sextet(n, 1) or "="
	end
	return table.concat(result)
end

local function base64_encode(data)
	if crypt and crypt.base64encode then
		local ok, result = pcall(crypt.base64encode, data)
		if ok and type(result) == "string" then
			return result
		end
	end
	return manual_base64(data)
end

local function timed_call(timeout, fn, ...)
	local args = table.pack(...)
	local done = false
	local ok = false
	local result = nil
	task.spawn(function()
		ok, result = pcall(fn, table.unpack(args, 1, args.n))
		done = true
	end)
	local started = os.clock()
	while not done and os.clock() - started < timeout do
		task.wait()
	end
	if not done then
		return false, "timeout"
	end
	return ok, result
end

local apiCache = {}
local lastRequest = 0
local apiOk = 0
local apiFail = 0

local function is_valid_source(src)
	if type(src) ~= "string" or src == "" then
		return false
	end
	local lower = src:lower()
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

local function throttle()
	local elapsed = os.clock() - lastRequest
	if elapsed < API_INTERVAL then
		task.wait(API_INTERVAL - elapsed)
	end
end

local function request_source(url, bodyKey, encoded, fields)
	if not httpRequest then
		return nil, "request is not supported"
	end
	throttle()
	local ok, response = pcall(httpRequest, {
		Url = url,
		Method = "POST",
		Headers = {["Content-Type"] = "application/json"},
		Body = HttpService:JSONEncode({[bodyKey] = encoded}),
	})
	lastRequest = os.clock()
	if not ok then
		return nil, tostring(response)
	end
	if type(response) ~= "table" or response.StatusCode ~= 200 or not response.Body or response.Body == "" then
		return nil, "HTTP " .. tostring(type(response) == "table" and response.StatusCode or "?")
	end
	local parsed, data = pcall(HttpService.JSONDecode, HttpService, response.Body)
	local source = nil
	if parsed and type(data) == "table" then
		for _, field in ipairs(fields) do
			if type(data[field]) == "string" then
				source = data[field]
				break
			end
		end
	elseif not parsed then
		source = response.Body
	end
	if is_valid_source(source) then
		return source
	end
	return nil, "invalid response"
end

local function api_decompile(bc)
	local cached = apiCache[bc]
	if cached then
		return cached.source, cached.method
	end
	local encoded = base64_encode(bc)
	local source = request_source("https://api.lua.expert/decompile", "script", encoded, {"source", "result", "output", "decompiled"})
	local method = "api_lua_expert"
	if not source then
		source = request_source("https://lua-decompiler.ferib.dev/decompile", "bytecode", encoded, {"source", "result", "output", "decompiled", "code"})
		method = "api_ferib"
	end
	if source then
		apiCache[bc] = {source = source, method = method}
		apiOk += 1
		return source, method
	end
	apiFail += 1
	return nil
end

local function extract_strings(bc)
	local result = {}
	local seen = {}
	for text in bc:gmatch("[ -~]+") do
		if #text >= 4 and not seen[text] then
			seen[text] = true
			table.insert(result, text)
		end
	end
	return result
end

local function extract_constants(script)
	if not getscriptclosure then
		return nil
	end
	local ok, closure = pcall(getscriptclosure, script)
	if not ok or not closure then
		return nil
	end
	local ok2, consts = pcall(debug.getconstants, closure)
	if not ok2 or type(consts) ~= "table" then
		return nil
	end
	local lines = {"constants via debug.getconstants"}
	for _, v in ipairs(consts) do
		if type(v) == "string" and #v >= 4 then
			table.insert(lines, v)
		end
	end
	if #lines <= 1 then
		return nil
	end
	return table.concat(lines, "\n"), "constants"
end

local intercepted = {}
local interceptedCount = 0
local originalLoadstring = nil

local function hook_callback(src, chunkname)
	if type(src) == "string" and #src > 100 and is_valid_source(src) then
		local key = sanitize(tostring(chunkname or src:sub(1, 60)))
		if not intercepted[key] then
			interceptedCount += 1
		end
		intercepted[key] = src
	end
	return originalLoadstring(src, chunkname)
end

local function install_hook()
	if oth and oth.hook then
		local ok, original = pcall(oth.hook, loadstring, hook_callback)
		if ok and type(original) == "function" then
			originalLoadstring = original
			return true
		end
	elseif hookfunction then
		local wrap = newcclosure or function(fn)
			return fn
		end
		local ok, original = pcall(hookfunction, loadstring, wrap(hook_callback))
		if ok and type(original) == "function" then
			originalLoadstring = original
			return true
		end
	end
	return false
end

local function restore_hook()
	if not originalLoadstring then
		return
	end
	originalLoadstring = nil
	if oth and oth.unhook then
		pcall(oth.unhook, loadstring)
	elseif restorefunction then
		pcall(restorefunction, loadstring)
	end
end

local function local_decompile(target)
	if not decompile then
		return nil
	end
	local ok, result = timed_call(DECOMPILE_TIMEOUT, decompile, target)
	if ok and is_valid_source(result) then
		return result
	end
	return nil
end

local function try_decompile(script, bc)
	local fullName = ""
	pcall(function()
		fullName = script:GetFullName()
	end)

	local hit = intercepted[sanitize(fullName)]
	if hit then
		return hit, "intercepted"
	end

	local direct = local_decompile(script)
	if direct then
		return direct, "local_direct"
	end

	if getscriptclosure then
		local ok, closure = pcall(getscriptclosure, script)
		if ok and closure then
			local fromClosure = local_decompile(closure)
			if fromClosure then
				return fromClosure, "local_closure"
			end
		end
	end

	if getsenv then
		local ok, senv = pcall(getsenv, script)
		if ok and type(senv) == "table" then
			local tried = 0
			for _, v in pairs(senv) do
				if type(v) == "function" then
					tried += 1
					local fromEnv = local_decompile(v)
					if fromEnv then
						return fromEnv, "local_senv"
					end
					if tried >= SENV_LIMIT then
						break
					end
				end
			end
		end
	end

	local apiSource, apiMethod = api_decompile(bc)
	if apiSource then
		return apiSource, apiMethod
	end

	local constants, constantsMethod = extract_constants(script)
	if constants then
		return constants, constantsMethod
	end

	local strs = extract_strings(bc)
	if #strs > 0 then
		local lines = {"bytecode v" .. tostring(bc:byte(1) or 0)}
		for _, s in ipairs(strs) do
			table.insert(lines, s)
		end
		return table.concat(lines, "\n"), "strings"
	end

	return nil, nil
end

local function scan_remotes(src)
	local found = {}
	local patterns = {
		":FireServer", ":InvokeServer", ":FireClient",
		":FireAllClients", ".OnServerEvent", ".OnClientEvent",
		".OnServerInvoke", ".OnClientInvoke",
		"RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent",
	}
	for _, pattern in ipairs(patterns) do
		if src:find(pattern, 1, true) then
			table.insert(found, pattern)
		end
	end
	return found
end

local KEYWORDS = {
	farm = {"farm", "collect", "harvest", "gather", "auto", "loop", "repeat", "while true", "wait", "task.wait", "yield", "gold", "coin", "cash", "resource", "ore", "wood", "fish", "crop", "plant", "mine", "chop", "click", "idle", "rebirth", "prestige", "level", "xp", "exp", "currency"},
	movement = {"speed", "walkspeed", "jump", "jumppower", "fly", "noclip", "teleport", "tween", "moveto", "position", "cframe", "vehicle", "sit", "boost"},
	gui = {"screengui", "frame", "textlabel", "textbutton", "imagelabel", "imagebutton", "scrollingframe", "uilistlayout", "uipadding", "uicorner", "visible", "enabled", "toggle", "menu", "hub", "panel", "window", "notify", "notification", "popup"},
	network = {"remotevent", "remotefunction", "fireserver", "invokeserver", "fireclient", "fireallclients", "onserverevent", "onclientevent", "unreliable", "bindable", "bind"},
	util = {"module", "require", "service", "getservice", "waitforchild", "findfirstchild", "findfirstchildofclass", "getdescendants", "getchildren", "instance", "new", "clone", "destroy", "connect", "disconnect", "event"},
}

local function classify_script(src)
	local tags = {}
	local lower = src:lower()
	for category, words in pairs(KEYWORDS) do
		local score = 0
		for _, word in ipairs(words) do
			if lower:find(word, 1, true) then
				score += 1
			end
		end
		if score >= 2 then
			table.insert(tags, category)
		end
	end
	return tags
end

local createdDirs = {}

local function ensure_dirs(path)
	local parts = {}
	for part in path:gmatch("[^/]+") do
		table.insert(parts, part)
	end
	local current = ""
	for index = 1, #parts - 1 do
		current = current == "" and parts[index] or (current .. "/" .. parts[index])
		if not createdDirs[current] then
			local ok, err = pcall(function()
				if not isfolder(current) then
					makefolder(current)
				end
			end)
			if not ok then
				return false, err
			end
			createdDirs[current] = true
		end
	end
	return true
end

local function write_file(path, content)
	local dirsOk, dirsError = ensure_dirs(path)
	if not dirsOk then
		return false, dirsError
	end
	return pcall(writefile, path, content)
end

local function resolve_output_path(root, script, fpath, ext)
	local class = script.ClassName
	local base
	if class == "ModuleScript" then
		base = root .. "/Modules"
	elseif class == "Script" then
		base = root .. "/Functions"
	else
		base = root .. "/Scripts"
	end
	return base .. "/" .. fpath .. ext
end

local function already_dumped(root, script, fpath)
	local exts = {get_extension(script), ".txt"}
	for _, ext in ipairs(exts) do
		if isfile(resolve_output_path(root, script, fpath, ext)) then
			return true
		end
	end
	return false
end

local function collect_instances(classes)
	local buckets = {}
	for _, class in ipairs(classes) do
		buckets[class] = {}
	end
	local seen = {}

	local function scan(list)
		for _, inst in ipairs(list) do
			local bucket = buckets[inst.ClassName]
			if bucket and not seen[inst] then
				seen[inst] = true
				local ok, path = pcall(inst.GetFullName, inst)
				if ok then
					table.insert(bucket, path)
				end
			end
		end
	end

	local sources = {
		{"GetDescendants", function()
			return game:GetDescendants()
		end},
		{"getinstances", getinstances},
		{"getnilinstances", getnilinstances},
	}

	for _, source in ipairs(sources) do
		local name, getter = source[1], source[2]
		if getter then
			local ok, list = pcall(getter)
			if ok and type(list) == "table" then
				local scanned, err = pcall(scan, list)
				if not scanned then
					fail("Remotes", name .. ": " .. tostring(err), "error_remotes_" .. name, 5)
				end
			elseif not ok then
				fail("Remotes", name .. ": " .. tostring(list), "error_remotes_" .. name, 5)
			end
		end
	end

	return buckets
end

local function unique_path(context, fpath)
	local count = (context.usedPaths[fpath] or 0) + 1
	context.usedPaths[fpath] = count
	if count == 1 then
		return fpath
	end
	return fpath .. "_" .. count
end

local function process_script(context, script)
	local stats = context.stats
	local fpath = build_path(script)
	if fpath == "" then
		return
	end

	local bc = get_bytecode(script)
	local version = bc and bc:byte(1) or 0
	local vkey = "v" .. version
	local fullName = script:GetFullName()

	stats.versions[vkey] = (stats.versions[vkey] or 0) + 1
	table.insert(context.scriptList, "[" .. vkey .. "] " .. script.ClassName .. " " .. fullName)

	if not bc then
		stats.empty += 1
		return
	end

	fpath = unique_path(context, fpath)

	if context.resuming and already_dumped(context.root, script, fpath) then
		stats.skipped += 1
		return
	end

	local source, method = try_decompile(script, bc)
	if not source then
		stats.empty += 1
		return
	end

	local isText = method == "strings" or method == "constants"
	local isApi = method:find("api", 1, true) ~= nil
	local ext = isText and ".txt" or get_extension(script)
	local path = resolve_output_path(context.root, script, fpath, ext)

	local written, writeError = write_file(path, source)
	if not written then
		stats.failed += 1
		fail("Escrita", fullName .. ": " .. tostring(writeError), "error_write", 5)
		return
	end

	if not isText then
		local tags = classify_script(source)
		if #tags > 0 then
			table.insert(context.taggedList, table.concat(tags, " | ") .. " | " .. fullName)
		end
		local calls = scan_remotes(source)
		if #calls > 0 then
			table.insert(context.remoteLogs, {path = fullName, calls = calls})
		end
	end

	if isText then
		stats.strings += 1
	elseif isApi then
		stats.api += 1
		stats.decompiled += 1
	else
		stats.decompiled += 1
	end
end

local function save_report(path, content)
	local ok, err = write_file(path, content)
	if not ok then
		fail("Escrita", path .. ": " .. tostring(err), "error_write", 5)
	end
end

local function dump_scripts(context, scripts)
	local stats = context.stats
	for index, script in ipairs(scripts) do
		local ok, err = pcall(process_script, context, script)
		if not ok then
			stats.failed += 1
			fail("Script", err, "error_script_item", 5)
		end
		if index % YIELD_EVERY == 0 then
			task.wait()
		end
	end

	for name, src in pairs(intercepted) do
		save_report(context.root .. "/Intercepted/" .. name .. ".lua", src)
	end

	if #context.scriptList > 0 then
		save_report(context.root .. "/Info/scripts.txt", table.concat(context.scriptList, "\n"))
	end
	if #context.taggedList > 0 then
		save_report(context.root .. "/Info/tagged.txt", table.concat(context.taggedList, "\n"))
	end
end

local function dump_remotes(context)
	local classes = {"RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent", "BindableEvent", "BindableFunction"}
	local buckets = collect_instances(classes)
	local allLines = {}
	local total = 0

	for _, class in ipairs(classes) do
		local paths = buckets[class]
		if #paths > 0 then
			total += #paths
			local lines = {class .. " (" .. #paths .. ")"}
			for _, p in ipairs(paths) do
				table.insert(lines, "  " .. p)
			end
			local content = table.concat(lines, "\n")
			save_report(context.root .. "/Remotes/" .. class .. ".txt", content)
			table.insert(allLines, content)
		end
	end

	if #allLines > 0 then
		save_report(context.root .. "/Remotes/todos.txt", table.concat(allLines, "\n\n"))
	end

	if #context.remoteLogs > 0 then
		local lines = {"chamadas de remotes detectadas\n"}
		for _, entry in ipairs(context.remoteLogs) do
			table.insert(lines, entry.path)
			for _, c in ipairs(entry.calls) do
				table.insert(lines, "  " .. c)
			end
		end
		save_report(context.root .. "/Remotes/calls.txt", table.concat(lines, "\n"))
	end

	return total
end

local function main()
	local missing = {}
	if not getscripts then
		table.insert(missing, "getscripts")
	end
	if not getscriptbytecode then
		table.insert(missing, "getscriptbytecode")
	end
	if not writefile then
		table.insert(missing, "writefile")
	end
	if not makefolder then
		table.insert(missing, "makefolder")
	end
	if not isfolder then
		table.insert(missing, "isfolder")
	end
	if not isfile then
		table.insert(missing, "isfile")
	end
	if #missing > 0 then
		fail("Executor", "Funcoes nao suportadas: " .. table.concat(missing, ", "), "error_executor", 0)
		return
	end

	if setstackhidden then
		pcall(setstackhidden, try_decompile, true)
		pcall(setstackhidden, api_decompile, true)
		pcall(setstackhidden, write_file, true)
		pcall(setstackhidden, hook_callback, true)
	end

	if not install_hook() then
		warn("Interceptacao de loadstring indisponivel neste executor.")
	end

	local placeId, gameName = get_placeinfo()
	local root = gameName .. "_" .. tostring(placeId)
	local resuming = isfolder(root)

	if not resuming then
		local ok = pcall(makefolder, root)
		if not ok then
			root = "bytecore_" .. tostring(placeId)
			resuming = isfolder(root)
			if not resuming then
				local created, err = pcall(makefolder, root)
				if not created then
					fail("Pasta", err, "error_folder", 0)
					return
				end
			end
		end
	end

	Notify({
		Title = "bytecore",
		Description = (resuming and "Continuando | " or "Iniciando | ") .. gameName .. " | " .. placeId,
		Duration = 5,
	})

	local listed, scripts = pcall(getscripts)
	if not listed or type(scripts) ~= "table" then
		fail("getscripts", scripts, "error_getscripts", 0)
		return
	end

	local context = {
		root = root,
		resuming = resuming,
		usedPaths = {},
		scriptList = {},
		taggedList = {},
		remoteLogs = {},
		stats = {
			decompiled = 0,
			api = 0,
			strings = 0,
			empty = 0,
			skipped = 0,
			failed = 0,
			versions = {},
		},
	}

	dump_scripts(context, scripts)

	if interceptedCount > 0 then
		print("Interceptados via loadstring: " .. interceptedCount)
	end

	local stats = context.stats
	local skipMsg = stats.skipped > 0 and (" | Pulados: " .. stats.skipped) or ""
	local failMsg = stats.failed > 0 and (" | Falhas: " .. stats.failed) or ""
	Notify({
		Title = "bytecore | Scripts",
		Description = "Decompilados: " .. stats.decompiled .. " | API: " .. stats.api .. " | Strings: " .. stats.strings .. " | Vazios: " .. stats.empty .. skipMsg .. failMsg,
		Duration = 6,
	})

	local totalRemotes = dump_remotes(context)

	Notify({
		Title = "bytecore | Remotes",
		Description = "Total: " .. totalRemotes .. " | API ok: " .. apiOk .. " | Falhas: " .. apiFail,
		Duration = 5,
	})

	local dominant = "nenhum"
	local maxCount = 0
	for version, count in pairs(stats.versions) do
		if count > maxCount then
			maxCount = count
			dominant = version
		end
	end

	task.wait(1)

	Notify({
		Title = "bytecore | Finalizado",
		Description = gameName .. " | " .. placeId .. " | Versao: " .. dominant,
		Duration = 8,
	})
end

local ok, err = xpcall(main, function(message)
	return debug.traceback(tostring(message), 2)
end)

restore_hook()

if not ok then
	local text = tostring(err)
	local first = string.match(text, "^[^\n]*") or text
	pcall(rawWarn, text)
	fail("Erro fatal", first, "error_fatal", 0)
end