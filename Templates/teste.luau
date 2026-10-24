-- // Inicializacao
if not getgenv then
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local env = getgenv()
local LOG_FILE = "Quests.txt"
local RACE_NPC_ID = "shax_race"
local canWrite = type(writefile) == "function" and type(appendfile) == "function"
local LocalPlayer = Players.LocalPlayer
local fishPause

local previous = env.QuestAutoState
if previous then
    previous.active = false
    if os.clock() - (previous.beat or 0) <= 120 then
        return
    end
    env.QuestAutoState = nil
end

local state: any = {
    active = true,
    beat = os.clock(),
    connections = {},
    attempts = {},
    last = {},
    warned = {},
    logged = {},
    logAt = {},
    retryAt = {},
    stuckUntil = {},
    misses = {},
    skipAccept = {},
    refused = {},
    giveReady = {},
    usedNode = {},
    fishPools = {},
    poolCooldown = {},
    poolTries = {},
    badAnchor = {},
    indexNeed = {},
    indexCooldown = {},
    caughtIds = {},
    objProgress = {},
    collected = {},
    loadoutQuests = {},
    npcArea = {},
    poolSpots = type(env.QuestAutoPoolSpots) == "table" and env.QuestAutoPoolSpots or {},
    order = {},
    orderCount = 0,
    npcPositions = {
        halden_sg = Vector3.new(-113.97261, -26.91625, 75.07424),
        oswald_sg = Vector3.new(-88.73578, -26.58293, 104.30929),
        shax_sg = Vector3.new(-39.42951, -7.34625, -101.16847),
        theodore_sg = Vector3.new(-122.92810, 5.14721, -91.85408),
        elanor_sg = Vector3.new(95.55070, -17.58002, -201.31857),
        julian_sg = Vector3.new(126.77348, -16.93007, -92.08841),
        bennie_sg = Vector3.new(-213.70196, -22.02900, 125.76802),
        cal_sg = Vector3.new(-201.56597, -18.50900, 67.75698),
        leo_sg = Vector3.new(248.77464, 6.16994, -154.93053),
        jane_sg = Vector3.new(233.88437, -4.33942, -70.95144),
        jones_sg = Vector3.new(198.72846, -3.26001, 166.52112),
        kent_sg = Vector3.new(275.73560, 7.26999, -245.78245),
        luca_sg = Vector3.new(-251.76531, -21.93002, 208.13259),
        shax_race = Vector3.new(386.64996, -220.21384, 550.45007),
        fenna_sg = Vector3.new(13.09099, -21.76751, 385.97069),
        ogg_sg = Vector3.new(100.51649, -21.91627, 310.37607),
        arabella_sg = Vector3.new(-180.43596, -30.66828, 334.70034),
        marina_bc = Vector3.new(-341.98370, -71.99586, 690.50214),
        marnie_bc = Vector3.new(-166.85906, -51.97036, 723.22812),
        toma_bc = Vector3.new(-548.93127, -12.74759, 735.15277),
        arabella_bc = Vector3.new(-504.49542, -11.25001, 838.55957),
        rusk_bc = Vector3.new(-550.95471, -21.69585, 937.94318),
        pell_bc = Vector3.new(-373.48364, -11.99582, 922.00214),
        bram_bc = Vector3.new(-379.48367, -2.49576, 1244.50220),
        morrissey_bc = Vector3.new(-728.45392, -31.79300, 1168.33105),
        senna_bc = Vector3.new(-470.98340, -2.49600, 1262.00208),
        marcus_bc = Vector3.new(-366.64279, -35.74576, 1177.48608),
        odin_bc = Vector3.new(-567.98364, 12.50403, 1393.50195),
        otto_sr = Vector3.new(-672.61378, -49.24586, 1045.54285),
        jun_sr = Vector3.new(-724.90771, -51.49600, 915.40125),
        yami_sr = Vector3.new(-861.08099, -48.50002, 1135.95093),
        morrissey_sr = Vector3.new(-726.84668, -31.79299, 1173.28064),
    },
}
env.QuestAutoState = state
env.QuestAutoPoolSpots = state.poolSpots

if type(env.QuestAutoNpcCache) == "table" then
    for npcId, position in pairs(env.QuestAutoNpcCache) do
        if typeof(position) == "Vector3" and not state.npcPositions[npcId] then
            state.npcPositions[npcId] = position
        end
    end
end
env.QuestAutoNpcCache = state.npcPositions

if canWrite then
    pcall(writefile, LOG_FILE, "")
end

-- // Utilidades
local function log(text)
    if canWrite then
        pcall(appendfile, LOG_FILE, "[" .. os.date("%H:%M:%S") .. "] " .. text .. "\n")
    end
end

local function norm(text)
    return (tostring(text):lower():gsub("[^%a]", ""))
end

local function flat(text)
    return (tostring(text):lower():gsub("[^%w]", ""))
end

local function clean(text)
    return (tostring(text):gsub("<[^>]+>", ""))
end

local function stripCounters(text)
    return (tostring(text):gsub("%(%d+/%d+%)", "()"))
end

local function serialize(value, depth, seen)
    depth = depth or 0
    seen = seen or {}
    local kind = typeof(value)
    if kind == "table" then
        if seen[value] or depth > 3 then
            return "{...}"
        end
        seen[value] = true
        local parts = {}
        for k, v in pairs(value) do
            parts[#parts + 1] = tostring(k) .. " = " .. serialize(v, depth + 1, seen)
        end
        seen[value] = nil
        table.sort(parts)
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif kind == "string" then
        return string.format("%q", value)
    elseif kind == "Instance" then
        local ok, name = pcall(value.GetFullName, value)
        return ok and name or tostring(value)
    end
    return tostring(value)
end

local function formatArgs(args)
    local parts = {}
    for i = 1, args.n do
        parts[#parts + 1] = serialize(args[i])
    end
    return table.concat(parts, ", ")
end

local function warnOnce(key, text)
    if not state.warned[key] then
        state.warned[key] = true
        log(text)
    end
end

local function logChange(key, text)
    if state.logged[key] ~= text then
        state.logged[key] = text
        log(text)
    end
end

local function logEvery(key, seconds, text)
    local now = os.clock()
    if now - (state.logAt[key] or -1000) >= seconds then
        state.logAt[key] = now
        log(text)
    end
end

local function findPath(root, ...)
    local node = root
    for _, name in ipairs({...}) do
        node = node and node:FindFirstChild(name)
    end
    return node
end

local function load(...)
    local node = findPath(ReplicatedStorage, ...)
    if not node then
        return nil
    end
    local ok, module = pcall(require, node)
    return ok and module or nil
end

local function pathKey(path)
    local parts = {}
    for _, part in ipairs(path) do
        parts[#parts + 1] = tostring(part)
    end
    return table.concat(parts, ".")
end

-- // Modulos do jogo
local Remotes = ReplicatedStorage:WaitForChild("Network"):WaitForChild("Remotes")
local Quests = load("Shared", "Data", "Quests")
local Areas = load("Shared", "Data", "Areas")
local Tracked = load("Client", "UI", "HUD", "TrackedQuests")
local QuestLog = load("Client", "UI", "Windows", "QuestLog")
local DialogueRemote = Remotes:FindFirstChild("Dialogue")
local LoadoutRemote = Remotes:FindFirstChild("Loadout")

local okRegistry, Registry = pcall(function()
    return require(ReplicatedStorage.Client.Core.Registry)
end)
local InventoryController = okRegistry and Registry.C and Registry.C.Inventory
local MinigameController = okRegistry and Registry.C and Registry.C.Minigame
local AreaController = okRegistry and Registry.C and Registry.C.Area

local areaKeys = {}
if type(Areas) == "table" then
    for key in pairs(Areas) do
        areaKeys[norm(key)] = tostring(key)
    end
end

local function currentArea()
    local value = AreaController and AreaController.Current
    if type(value) ~= "string" then
        value = state.location
    end
    return value
end

local function untuckQuests()
    if not LoadoutRemote then
        return false
    end
    local ok = pcall(LoadoutRemote.FireServer, LoadoutRemote, "setSetting", {id = "trackedQuestsTucked", value = false})
    log("Loadout setSetting trackedQuestsTucked=false -> " .. tostring(ok))
    return ok
end

-- // Anti AFK
do
    local VirtualUser = game:GetService("VirtualUser")

    local function antiAfkPulse()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end

    state.connections[#state.connections + 1] = LocalPlayer.Idled:Connect(function()
        if not state.active then
            return
        end
        antiAfkPulse()
        logEvery("antiafk", 30, "Anti AFK acionado")
    end)

    task.spawn(function()
        while state.active do
            task.wait(60)
            if state.active then
                antiAfkPulse()
            end
        end
    end)
end

-- // Monitor de remotes
do
    local watchedIn = {
        Dialogue = true,
        Location = true,
        ShaxRace = true,
        Minigame = true,
        Ocarina = true,
        Render = true,
        Quest = true,
    }

    local loggedIn = {
        Dialogue = true,
        ShaxRace = true,
        Ocarina = true,
        Quest = true,
    }

    local loggedOut = {
        Dialogue = true,
        Loadout = true,
        Ocarina = true,
        Quest = true,
        ShaxRace = true,
    }

    local function spyAllowed(name)
        state.spyCounts = state.spyCounts or {}
        local count = (state.spyCounts[name] or 0) + 1
        state.spyCounts[name] = count
        return count <= 300
    end

    local function isLocalRef(value: any)
        if value == LocalPlayer.UserId or value == LocalPlayer.Name or value == LocalPlayer then
            return true
        end
        if typeof(value) == "Instance" then
            local character = LocalPlayer.Character
            return character ~= nil and (value == character or value:IsDescendantOf(character))
        end
        return false
    end

    local function mentionsLocal(action: any, args: any)
        if isLocalRef(action) then
            return true
        end
        for i = 1, args.n do
            local value = args[i]
            if isLocalRef(value) then
                return true
            end
            if type(value) == "table" then
                for _, inner in pairs(value) do
                    if isLocalRef(inner) then
                        return true
                    end
                end
            end
        end
        return false
    end

    local function onAreaChanged(name: any)
        if not state.active or type(name) ~= "string" then
            return
        end
        state.location = name
        state.fishRefused = 0
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root then
            state.poolSpots[norm(name)] = root.Position
        end
    end

    local function captureLoadout(args: any)
        local action = tostring(args[1] or ""):lower()
        local untrack = action:find("untrack", 1, true) ~= nil or action:find("remove", 1, true) ~= nil
        local function visit(value: any, depth: number)
            if depth > 3 then
                return
            end
            if type(value) == "string" then
                if Quests and type(Quests[value]) == "table" then
                    state.loadoutQuests[value] = not untrack
                end
            elseif type(value) == "table" then
                for _, inner in pairs(value) do
                    visit(inner, depth + 1)
                end
            end
        end
        for i = 1, args.n do
            visit(args[i], 0)
        end
    end

    local function onRemoteEvent(name: string, action: any, args: any)
        if name == "Dialogue" then
            state.dialogueSeq = (state.dialogueSeq or 0) + 1
        elseif name == "Location" and action == "update" then
            onAreaChanged(args[1])
        elseif name == "ShaxRace" and action == "state" then
            local wasRunning = type(state.raceState) == "table" and state.raceState.running == true
            state.raceState = args[1]
            if not wasRunning and type(args[1]) == "table" and args[1].running == true then
                state.raceStartedAt = os.clock()
            end
        elseif name == "Minigame" then
            if action == "refused" then
                state.fishRefused = (state.fishRefused or 0) + 1
                state.fishRefusedAt = os.clock()
            elseif action == "startMinigame" then
                state.fishRefused = 0
            end
            return
        elseif name == "Ocarina" and mentionsLocal(action, args) then
            state.ocarinaLocal = (state.ocarinaLocal or 0) + 1
            state.ocarinaUntil = os.clock() + 4
        elseif name == "Render" then
            if action == "catchAnnounce" then
                local info = args[1]
                if type(info) == "table" and info.name == LocalPlayer.Name then
                    log("Voce pescou " .. tostring(info.itemId))
                end
            end
            return
        end
        if loggedIn[name] and spyAllowed("in:" .. name) then
            log("recebido " .. name .. ":" .. tostring(action) .. " " .. formatArgs(args))
        end
    end

    for name in pairs(watchedIn) do
        local remote = Remotes:FindFirstChild(name)
        if remote and remote:IsA("RemoteEvent") then
            state.connections[#state.connections + 1] = remote.OnClientEvent:Connect(function(action: any, ...)
                if not state.active then
                    return
                end
                onRemoteEvent(name, action, table.pack(...))
            end)
        end
    end

    if AreaController and AreaController.AreaChange then
        local okArea, areaConnection = pcall(function()
            return AreaController.AreaChange:Connect(onAreaChanged)
        end)
        if okArea and areaConnection then
            state.connections[#state.connections + 1] = areaConnection
        end
    end

    state.location = currentArea()

    env.QuestAutoHandler = function(remote: any, method: string, args: any)
        if env.QuestAutoState ~= state or not state.active then
            return
        end
        if typeof(remote) ~= "Instance" or remote.Parent ~= Remotes then
            return
        end
        local remoteName: any = (remote :: any).Name
        local first = args[1]
        if remoteName == "Inventory" then
            return
        end
        if remoteName == "Loadout" then
            pcall(captureLoadout, args)
        end
        local now = os.clock()
        if remoteName == "Dialogue" and now - (state.selfDialogueAt or 0) > 1.5 then
            local data = args[2]
            if first == "nodeAction" and type(data) == "table" and data.npc and data.node then
                env.QuestDialogueRecorded = env.QuestDialogueRecorded or {}
                env.QuestDialogueRecorded[tostring(data.npc) .. ":" .. tostring(data.node)] = args
                log("Dialogue gravado " .. tostring(data.npc) .. ":" .. tostring(data.node))
            end
        end
        if loggedOut[remoteName] and spyAllowed("out:" .. tostring(remoteName)) then
            log("enviado " .. tostring(remoteName) .. ":" .. method .. " " .. formatArgs(args))
        end
    end

    if not env.QuestAutoHooked and type(hookmetamethod) == "function" and type(getnamecallmethod) == "function" then
        env.QuestAutoHooked = true
        local old
        local function hook(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" or method == "InvokeServer" then
                local handler = env.QuestAutoHandler
                if handler then
                    local args = table.pack(...)
                    task.spawn(handler, self, method, args)
                end
            end
            return old(self, ...)
        end
        old = hookmetamethod(game, "__namecall", newcclosure and newcclosure(hook) or hook)
    end

    if not env.QuestAutoFireHooked and type(hookfunction) == "function" and DialogueRemote then
        env.QuestAutoFireHooked = true
        pcall(function()
            local originalFire
            local function fire(self, ...)
                local handler = env.QuestAutoHandler
                if handler and typeof(self) == "Instance" then
                    local args = table.pack(...)
                    task.spawn(handler, self, "FireServer", args)
                end
                return originalFire(self, ...)
            end
            originalFire = hookfunction(DialogueRemote.FireServer, newcclosure and newcclosure(fire) or fire)
        end)
    end

    if not env.QuestAutoLoadoutHooked and type(hookfunction) == "function" and LoadoutRemote then
        env.QuestAutoLoadoutHooked = true
        pcall(function()
            local originalLoadout
            local function fireLoadout(self, ...)
                local handler = env.QuestAutoHandler
                if handler and typeof(self) == "Instance" then
                    local args = table.pack(...)
                    task.spawn(handler, self, "FireServer", args)
                end
                return originalLoadout(self, ...)
            end
            originalLoadout = hookfunction(LoadoutRemote.FireServer, newcclosure and newcclosure(fireLoadout) or fireLoadout)
        end)
    end
end

-- // Indice de dialogos
local index = {accept = {}, complete = {}, setData = {}, refs = {}}
local knownNpcs = {}
local npcModules = {}
local npcRoot = findPath(ReplicatedStorage, "Shared", "Data", "NPCs")

local function addIndex(bucket, key, npc, node, kind)
    bucket[key] = bucket[key] or {}
    table.insert(bucket[key], {npc = npc, node = node, kind = kind})
end

local function buildIndex()
    if not npcRoot then
        return
    end
    for _, inst in ipairs(npcRoot:GetDescendants()) do
        if inst:IsA("ModuleScript") then
            local ok, module = pcall(require, inst)
            if ok and type(module) == "table" and type(module.nodes) == "table" then
                knownNpcs[inst.Name] = true
                npcModules[inst.Name] = module
                for nodeName, node in pairs(module.nodes) do
                    if type(node) == "table" and type(node.serverActions) == "table" then
                        for _, action in ipairs(node.serverActions) do
                            if type(action) == "table" then
                                for _, value in pairs(action) do
                                    if type(value) == "string" then
                                        addIndex(index.refs, value, inst.Name, nodeName, action.type)
                                    elseif type(value) == "table" then
                                        for _, part in pairs(value) do
                                            if type(part) == "string" then
                                                addIndex(index.refs, part, inst.Name, nodeName, action.type)
                                            end
                                        end
                                    end
                                end
                                if action.type == "acceptQuest" and action.quest then
                                    addIndex(index.accept, action.quest, inst.Name, nodeName)
                                elseif action.type == "completeQuest" and action.quest then
                                    addIndex(index.complete, action.quest, inst.Name, nodeName)
                                elseif action.type == "setData" and type(action.path) == "table" then
                                    addIndex(index.setData, pathKey(action.path), inst.Name, nodeName)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    for _, bucket in pairs(index) do
        for _, list in pairs(bucket) do
            table.sort(list, function(a, b)
                return a.npc .. a.node < b.npc .. b.node
            end)
        end
    end
end

buildIndex()

local function countKeys(bucket)
    local n = 0
    for _ in pairs(bucket) do
        n = n + 1
    end
    return n
end

log("Indice de dialogos: accept=" .. countKeys(index.accept) .. " complete=" .. countKeys(index.complete) .. " setData=" .. countKeys(index.setData) .. " refs=" .. countKeys(index.refs) .. " npcs=" .. countKeys(knownNpcs))

-- // Movimento
local noclipConnection
local originalCollide = {}

local function getRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart"), character
end

local function isAlive()
    local character = LocalPlayer.Character
    if not character or not character.Parent then
        return false
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    return humanoid ~= nil and root ~= nil and humanoid.Health > 0
end

local function waitAlive()
    if isAlive() then
        return false
    end
    log("Personagem morreu, aguardando respawn")
    if fishPause then
        fishPause()
    end
    while state.active and not isAlive() do
        state.beat = os.clock()
        task.wait(0.25)
    end
    if not state.active then
        return true
    end
    task.wait(1.5)
    state.deaths = (state.deaths or 0) + 1
    log("Personagem respawnou, continuando (mortes=" .. state.deaths .. ")")
    return true
end

local function deathWatcher()
    local wasAlive = isAlive()
    while state.active do
        task.wait(0.25)
        local alive = isAlive()
        if wasAlive and not alive and fishPause then
            task.spawn(fishPause)
        end
        wasAlive = alive
    end
end

local function hoverOffset()
    return Vector3.new(0, tonumber(env.QuestFlyHeight) or 6, 0)
end

local function noclipOn()
    if noclipConnection then
        return
    end
    local parts = {}
    local refreshedAt = 0
    noclipConnection = RunService.Stepped:Connect(function()
        local _, character = getRoot()
        if not character then
            return
        end
        local now = os.clock()
        if now - refreshedAt > 1 then
            refreshedAt = now
            parts = {}
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    parts[#parts + 1] = part
                    if originalCollide[part] == nil then
                        originalCollide[part] = part.CanCollide
                    end
                end
            end
        end
        for _, part in ipairs(parts) do
            part.CanCollide = false
        end
    end)
end

local function noclipOff()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    for part, value in pairs(originalCollide) do
        pcall(function()
            part.CanCollide = value
        end)
    end
    originalCollide = {}
end

local function speed()
    return tonumber(env.QuestFlySpeed) or 90
end

local function flyTo(position, maxSpeed)
    if fishPause then
        fishPause()
    end
    local started = os.clock()
    noclipOn()
    while state.active do
        if os.clock() - started > 90 then
            log("Voo excedeu o tempo")
            return false
        end
        local dt = RunService.Heartbeat:Wait()
        local root = getRoot()
        if not isAlive() or not root then
            waitAlive()
            started = os.clock()
            continue
        end
        local delta = position - root.Position
        local distance = delta.Magnitude
        if distance < 1.5 then
            return true
        end
        local step = math.min(distance, (maxSpeed or speed()) * dt)
        root.CFrame = CFrame.new(root.Position + delta.Unit * step) * (root.CFrame - root.CFrame.Position)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    return false
end

local function pivotPosition(inst)
    local ok, pivot = pcall(function()
        return inst:GetPivot().Position
    end)
    return ok and pivot or nil
end

local function streamAt(position)
    pcall(function()
        LocalPlayer:RequestStreamAroundAsync(position, 5)
    end)
end

local function firePrompt(inst)
    local prompt = inst:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt then
        local origin = pivotPosition(inst)
        if origin then
            for _, candidate in ipairs(Workspace:GetDescendants()) do
                if candidate:IsA("ProximityPrompt") and candidate.Parent and candidate.Parent:IsA("BasePart") then
                    if (candidate.Parent.Position - origin).Magnitude < 12 then
                        prompt = candidate
                        break
                    end
                end
            end
        end
    end
    if prompt and type(fireproximityprompt) == "function" then
        pcall(fireproximityprompt, prompt)
        return true
    end
    local click = inst:FindFirstChildWhichIsA("ClickDetector", true)
    if click and type(fireclickdetector) == "function" then
        pcall(fireclickdetector, click)
        return true
    end
    return false
end

-- // NPCs
local scan = {points = nil, cursor = 1, running = false, finishedAt = 0}

local function findNpc(id)
    local folder = findPath(Workspace, "World", "NPCs")
    local found = folder and folder:FindFirstChild(id, true)
    if found then
        return found
    end
    return Workspace:FindFirstChild(id, true)
end

local function recordNpcs()
    local folder = findPath(Workspace, "World", "NPCs")
    if not folder then
        return
    end
    for _, area in ipairs(folder:GetChildren()) do
        local members
        local grouped = area:IsA("Folder") or not area:FindFirstChildWhichIsA("Humanoid")
        if grouped then
            members = area:GetChildren()
        else
            members = {area}
        end
        for _, npc in ipairs(members) do
            local position = pivotPosition(npc)
            if grouped and position then
                state.npcArea[npc.Name] = norm(area.Name)
            end
            if position and not state.npcPositions[npc.Name] then
                state.npcPositions[npc.Name] = position
                log("NPC visto: " .. npc.Name .. " em " .. area.Name .. " @ " .. tostring(position))
            end
        end
    end
end

local function missingNpcCount()
    local count = 0
    for npcId in pairs(knownNpcs) do
        if not state.npcPositions[npcId] then
            count = count + 1
        end
    end
    return count
end

local function buildScanPoints()
    local heights = {}
    for _, position in pairs(state.npcPositions) do
        heights[#heights + 1] = position.Y
    end
    if #heights == 0 then
        return {}
    end
    table.sort(heights)
    local height = heights[math.ceil(#heights / 2)]
    local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
    for _, position in pairs(state.npcPositions) do
        if math.abs(position.Y - height) <= 100 then
            minX = math.min(minX, position.X)
            maxX = math.max(maxX, position.X)
            minZ = math.min(minZ, position.Z)
            maxZ = math.max(maxZ, position.Z)
        end
    end
    if minX == math.huge then
        return {}
    end
    local padding = tonumber(env.QuestScanPadding) or 250
    local step = tonumber(env.QuestScanStep) or 160
    local points = {}
    local x = minX - padding
    while x <= maxX + padding do
        local z = minZ - padding
        while z <= maxZ + padding do
            points[#points + 1] = Vector3.new(x, height, z)
            z = z + step
        end
        x = x + step
    end
    local root = getRoot()
    local origin = root and root.Position
    if origin then
        table.sort(points, function(a, b)
            return (a - origin).Magnitude < (b - origin).Magnitude
        end)
    end
    return points
end

local function runScan(targetId)
    while state.active and scan.cursor <= #scan.points do
        if targetId and state.npcPositions[targetId] then
            return
        end
        local point = scan.points[scan.cursor]
        scan.cursor = scan.cursor + 1
        streamAt(point)
        task.wait(0.1)
        pcall(recordNpcs)
        if missingNpcCount() == 0 then
            scan.cursor = #scan.points + 1
        end
    end
end

local function scanNpcs(targetId)
    if scan.running then
        return false
    end
    if scan.points and scan.cursor > #scan.points and os.clock() - scan.finishedAt > 600 then
        scan.points = nil
        scan.cursor = 1
    end
    scan.points = scan.points or buildScanPoints()
    if scan.cursor > #scan.points then
        return targetId == nil or state.npcPositions[targetId] ~= nil
    end
    scan.running = true
    log("Varredura de NPCs iniciada: " .. #scan.points .. " pontos, faltando " .. missingNpcCount())
    local ok, err = pcall(runScan, targetId)
    scan.running = false
    if not ok then
        log("Erro na varredura de NPCs: " .. tostring(err))
    end
    if scan.cursor > #scan.points then
        scan.finishedAt = os.clock()
        log("Varredura de NPCs concluida, faltando " .. missingNpcCount())
    end
    return targetId == nil or state.npcPositions[targetId] ~= nil
end

local function npcFromText(text)
    local lower = tostring(text):lower()
    local ids = {}
    local listed = {}
    for npcId in pairs(state.npcPositions) do
        listed[npcId] = true
    end
    for npcId in pairs(knownNpcs) do
        listed[npcId] = true
    end
    for npcId in pairs(listed) do
        if npcId ~= RACE_NPC_ID then
            ids[#ids + 1] = npcId
        end
    end
    table.sort(ids)
    for _, npcId in ipairs(ids) do
        local name = npcId:match("^(.-)_")
        if name and name ~= "" and lower:find("%f[%a]" .. name .. "%f[%A]") then
            return npcId
        end
    end
    return nil
end

local function locateNpc(id)
    local npc = findNpc(id)
    if npc then
        return npc
    end
    local target = state.npcPositions[id]
    if not target then
        pcall(recordNpcs)
        if scan.running then
            local waited = 0
            while state.active and scan.running and not state.npcPositions[id] and waited < 60 do
                task.wait(0.5)
                waited = waited + 0.5
            end
        else
            pcall(scanNpcs, id)
        end
        pcall(recordNpcs)
        target = state.npcPositions[id]
        if not target then
            return findNpc(id)
        end
    end
    streamAt(target)
    task.wait(1)
    npc = findNpc(id)
    if npc then
        return npc
    end
    noclipOn()
    flyTo(target + hoverOffset())
    noclipOff()
    task.wait(1)
    return findNpc(id)
end

local function approachNpc(id)
    local npc = locateNpc(id)
    if not npc then
        local target = state.npcPositions[id]
        if target then
            log("NPC " .. id .. " nao carregado, indo na posicao salva")
            noclipOn()
            local arrived = flyTo(target + hoverOffset())
            noclipOff()
            return arrived, nil
        end
        warnOnce("npc:" .. id, "NPC nao encontrado: " .. id)
        return false, nil
    end
    local position = pivotPosition(npc)
    if not position then
        return false, npc
    end
    state.npcPositions[id] = position
    noclipOn()
    local arrived = flyTo(position + hoverOffset())
    noclipOff()
    return arrived, npc
end

local function talkToNpc(id)
    local arrived, npc = approachNpc(id)
    local fired = arrived and npc and firePrompt(npc)
    log("NPC " .. id .. " voo=" .. tostring(arrived) .. " interacao=" .. tostring(fired))
    return arrived
end

local function actOnNode(npc, node)
    if env.QuestAutoFly ~= false then
        local arrived = approachNpc(npc)
        if not arrived then
            if state.npcPositions[npc] or findNpc(npc) then
                return false
            end
            log("NPC " .. npc .. " desconhecido, enviando dialogo direto")
        end
    end
    if not DialogueRemote then
        return false
    end
    local before = state.dialogueSeq or 0
    local recorded = type(env.QuestDialogueRecorded) == "table" and env.QuestDialogueRecorded[npc .. ":" .. node]
    state.selfDialogueAt = os.clock()
    local ok
    if recorded then
        ok = pcall(DialogueRemote.FireServer, DialogueRemote, table.unpack(recorded, 1, recorded.n))
    else
        ok = pcall(DialogueRemote.FireServer, DialogueRemote, "nodeAction", {npc = npc, node = node})
    end
    local limit = before > 0 and 3 or 1
    local waited = 0
    while ok and waited < limit and (state.dialogueSeq or 0) == before do
        task.wait(0.25)
        waited = waited + 0.25
    end
    log("nodeAction " .. npc .. ":" .. node .. " -> " .. tostring(ok) .. " resposta=" .. tostring((state.dialogueSeq or 0) ~= before))
    return ok
end

-- // Objetos de quest
local sweepSkip = {"instruments", "seat", "portal", "teleport", "shop"}

local function objectFromText(text)
    local root = findPath(Workspace, "World", "QuestObjects")
    if not root then
        return nil
    end
    local words = {}
    for word in tostring(text):lower():gmatch("%a+") do
        if #word >= 5 then
            words[#words + 1] = word
        end
    end
    local best, bestScore
    for _, inst in ipairs(root:GetChildren()) do
        local name = norm(inst.Name)
        local score = 0
        for _, word in ipairs(words) do
            if name:find(norm(word), 1, true) then
                score = score + 1
            end
        end
        if score > 0 and (not bestScore or score > bestScore) then
            best, bestScore = inst, score
        end
    end
    return best
end

local function triggerPrompt(prompt)
    pcall(function()
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
    end)
    if type(fireproximityprompt) == "function" then
        pcall(fireproximityprompt, prompt)
        return true
    end
    return false
end

local function promptPosition(prompt)
    local holder = prompt.Parent
    if holder and holder:IsA("Attachment") then
        return holder.WorldPosition
    elseif holder then
        return pivotPosition(holder)
    end
    return nil
end

local function promptHolders(inst)
    local list = {}
    for _, descendant in ipairs(inst:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") and descendant.Enabled then
            local position = promptPosition(descendant)
            if position then
                list[#list + 1] = {prompt = descendant, position = position}
            end
        end
    end
    return list
end

local function collectStatues()
    local folder = findPath(Workspace, "World", "QuestObjects", "haldenStatues")
    local remote = Remotes:FindFirstChild("Quest")
    if not folder or not remote then
        return false
    end
    local targets = {}
    for _, child in ipairs(folder:GetChildren()) do
        if child.Name:lower():match("^statue%d+$") then
            targets[#targets + 1] = child
        end
    end
    table.sort(targets, function(a, b)
        return tonumber(a.Name:match("%d+")) < tonumber(b.Name:match("%d+"))
    end)
    noclipOn()
    for _, statue in ipairs(targets) do
        if not state.active then
            break
        end
        local position = pivotPosition(statue)
        if position then
            if not flyTo(position + hoverOffset()) then
                break
            end
            firePrompt(statue)
        end
        local ok = pcall(remote.FireServer, remote, "collectObject", statue.Name:lower())
        log("collectObject " .. statue.Name:lower() .. " -> " .. tostring(ok))
        task.wait(0.5 + math.random() * 0.3)
    end
    noclipOff()
    return true
end

local function sweepPrompts(position, radius)
    local npcs = findPath(Workspace, "World", "NPCs")
    local list = {}
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("ProximityPrompt") and inst.Enabled and not (npcs and inst:IsDescendantOf(npcs)) then
            local full = inst:GetFullName():lower()
            local blocked = false
            for _, word in ipairs(sweepSkip) do
                if full:find(word, 1, true) then
                    blocked = true
                    break
                end
            end
            local at = not blocked and promptPosition(inst)
            if at and (at - position).Magnitude <= radius then
                list[#list + 1] = {prompt = inst, position = at, distance = (at - position).Magnitude}
            end
        end
    end
    table.sort(list, function(a, b)
        return a.distance < b.distance
    end)
    local fired = 0
    for _, item in ipairs(list) do
        if fired >= 6 or not state.active then
            break
        end
        if flyTo(item.position + hoverOffset()) then
            triggerPrompt(item.prompt)
            fired = fired + 1
            log("Prompt acionado " .. item.prompt:GetFullName())
            task.wait(0.6)
        end
    end
    return fired
end

local function collectObjects(inst, sweep)
    local remote = Remotes:FindFirstChild("Quest")
    local questObjects = findPath(Workspace, "World", "QuestObjects")
    local entries = {}
    local holders = promptHolders(inst)
    if #holders > 1 then
        for _, holder in ipairs(holders) do
            entries[#entries + 1] = {position = holder.position, prompt = holder.prompt}
        end
    else
        local targets = {}
        if pivotPosition(inst) then
            targets[1] = inst
        else
            for _, child in ipairs(inst:GetChildren()) do
                targets[#targets + 1] = child
            end
        end
        for _, target in ipairs(targets) do
            entries[#entries + 1] = {inst = target, position = pivotPosition(target)}
        end
    end
    noclipOn()
    for _, entry in ipairs(entries) do
        if not state.active then
            break
        end
        local position = entry.position
        if position then
            if not flyTo(position + hoverOffset()) then
                break
            end
            if entry.prompt then
                triggerPrompt(entry.prompt)
            else
                firePrompt(entry.inst)
            end
        end
        if entry.inst and remote and questObjects and entry.inst:IsDescendantOf(questObjects) then
            local ok = pcall(remote.FireServer, remote, "collectObject", entry.inst.Name:lower())
            log("collectObject " .. entry.inst.Name:lower() .. " -> " .. tostring(ok))
        end
        if sweep and position then
            sweepPrompts(position, 60)
        end
        task.wait(0.5 + math.random() * 0.3)
    end
    noclipOff()
    return true
end

local function waypoints()
    local points = {}
    local root = getRoot()
    local origin = root and root.Position
    local radius = tonumber(env.QuestSearchRadius) or 700
    local function add(point)
        if point and (not origin or (point - origin).Magnitude <= radius) then
            points[#points + 1] = point
        end
    end
    local objects = findPath(Workspace, "World", "QuestObjects")
    if objects then
        for _, child in ipairs(objects:GetChildren()) do
            add(pivotPosition(child))
            for _, sub in ipairs(child:GetChildren()) do
                add(pivotPosition(sub))
            end
        end
    end
    if type(env.QuestSearchPoints) == "table" then
        for _, point in ipairs(env.QuestSearchPoints) do
            points[#points + 1] = point
        end
    end
    for _, point in pairs(state.npcPositions) do
        add(point)
    end
    return points
end

local function nameScore(name, words)
    local flatName = norm(name)
    local score = 0
    for _, word in ipairs(words) do
        local key = norm(word)
        if key ~= "" and flatName:find(key, 1, true) then
            score = score + 1
        end
    end
    return score
end

local function attributeText(inst)
    local parts = {}
    for _, attribute in ipairs({"itemId", "ItemId", "id", "Id", "item", "Item", "itemName", "ItemName"}) do
        local value = inst:GetAttribute(attribute)
        if type(value) == "string" then
            parts[#parts + 1] = value
        end
    end
    return table.concat(parts, " ")
end

local function findWorldItem(words, exclude)
    local npcs = findPath(Workspace, "World", "NPCs")
    local areaParts = findPath(Workspace, "World", "AreaParts")
    local characters = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            characters[#characters + 1] = player.Character
        end
    end
    local root = getRoot()
    local origin = root and root.Position
    local best, bestScore, bestDistance
    local areaBest, areaScore, areaDistance
    for _, inst in ipairs(Workspace:GetDescendants()) do
        local candidate, score
        local isPrompt = false
        if inst:IsA("ProximityPrompt") then
            if inst.Enabled then
                local holder = inst.Parent
                if holder then
                    isPrompt = true
                    candidate = holder:FindFirstAncestorOfClass("Model") or holder
                    local base = nameScore(inst.ObjectText .. " " .. inst.ActionText .. " " .. holder.Name .. " " .. candidate.Name .. " " .. attributeText(holder) .. " " .. attributeText(candidate), words)
                    score = base > 0 and base + 0.5 or 0
                end
            end
        elseif inst:IsA("Model") or inst:IsA("BasePart") or inst:IsA("Tool") then
            candidate = inst
            score = nameScore(inst.Name .. " " .. attributeText(inst), words)
        end
        if candidate and score and score > 0 and not (npcs and candidate:IsDescendantOf(npcs)) and not (exclude and exclude[candidate]) then
            local skip = false
            if not isPrompt and (candidate.Name:find("^Prop_") or candidate:FindFirstAncestor("Assets")) then
                skip = true
            end
            if not skip then
                for _, character in ipairs(characters) do
                    if candidate:IsDescendantOf(character) then
                        skip = true
                        break
                    end
                end
            end
            local position = not skip and pivotPosition(candidate)
            if position then
                local distance = origin and (position - origin).Magnitude or 0
                if areaParts and candidate:IsDescendantOf(areaParts) then
                    if not areaScore or score > areaScore or (score == areaScore and distance < areaDistance) then
                        areaBest, areaScore, areaDistance = candidate, score, distance
                    end
                elseif not bestScore or score > bestScore or (score == bestScore and distance < bestDistance) then
                    best, bestScore, bestDistance = candidate, score, distance
                end
            end
        end
    end
    return best or areaBest
end

local function searchItem(words)
    local points = waypoints()
    if #points == 0 then
        return nil
    end
    log("Procurando item " .. table.concat(words, ",") .. " em " .. #points .. " pontos")
    noclipOn()
    local found
    local root = getRoot()
    local current = root and root.Position
    local visited = 0
    while #points > 0 and state.active and not found and visited < 25 do
        local bestIndex, bestDistance = 1, math.huge
        for i, point in ipairs(points) do
            local distance = current and (point - current).Magnitude or 0
            if distance < bestDistance then
                bestIndex, bestDistance = i, distance
            end
        end
        local target = table.remove(points, bestIndex)
        if not flyTo(target + hoverOffset()) then
            break
        end
        current = target
        visited = visited + 1
        task.wait(0.4)
        found = findWorldItem(words)
    end
    noclipOff()
    return found
end

-- // Inventario
local inventoryModules

local function findInventoryModules()
    if inventoryModules then
        return inventoryModules
    end
    inventoryModules = {}
    local client = findPath(ReplicatedStorage, "Client")
    if client then
        for _, inst in ipairs(client:GetDescendants()) do
            if inst:IsA("ModuleScript") and inst.Name:lower():find("inventory", 1, true) then
                local ok, module = pcall(require, inst)
                if ok and type(module) == "table" and type(rawget(module, "Cache")) == "table" then
                    inventoryModules[#inventoryModules + 1] = module
                end
            end
        end
    end
    if #inventoryModules == 0 then
        log("Nenhum modulo de inventario encontrado em Client")
    end
    return inventoryModules
end

local function lookupSeq(module, key, entry)
    local map = rawget(module, "Seq")
    if type(map) ~= "table" then
        return nil
    end
    local ok, direct = pcall(function()
        return map[key] or (entry.uid and map[entry.uid]) or (entry.id and map[entry.id])
    end)
    if ok and type(direct) == "number" then
        return direct
    end
    for seq, value in pairs(map) do
        if type(seq) == "number" and (value == key or value == entry.uid or value == entry.id) then
            return seq
        end
    end
    return nil
end

local function inventoryItems()
    local items = {}
    for _, module in ipairs(findInventoryModules()) do
        local cache = rawget(module, "Cache")
        if type(cache) == "table" then
            for key, entry in pairs(cache) do
                if type(entry) == "table" then
                    items[#items + 1] = {
                        key = key,
                        id = rawget(entry, "id") or key,
                        itemType = rawget(entry, "itemType"),
                        seq = rawget(entry, "seq") or lookupSeq(module, key, entry),
                        module = module,
                        data = entry,
                    }
                end
            end
        end
    end
    if #items == 0 then
        warnOnce("inv:vazio", "Nenhum item no Cache do inventario")
    end
    return items
end

local itemLookup

local function loadItems()
    if itemLookup then
        return itemLookup
    end
    itemLookup = {}
    local dataRoot = findPath(ReplicatedStorage, "Shared", "Data")
    if not dataRoot then
        return itemLookup
    end
    for _, inst in ipairs(dataRoot:GetDescendants()) do
        if inst:IsA("ModuleScript") and inst.Name == "Items" then
            local ok, module = pcall(require, inst)
            if ok and type(module) == "table" then
                for key, def in pairs(module) do
                    if type(def) == "table" then
                        local entry = {key = tostring(key), def = def}
                        itemLookup[norm(key)] = entry
                        for _, field in ipairs({"displayName", "name", "label"}) do
                            local value = rawget(def, field)
                            if type(value) == "string" and value ~= "" and not itemLookup[norm(value)] then
                                itemLookup[norm(value)] = entry
                            end
                        end
                    end
                end
                break
            end
        end
    end
    return itemLookup
end

local function itemFromText(text, npcId)
    local lookup = loadItems()
    local npcName = npcId and npcId:match("^(.-)_") or ""
    local list = {}
    for word in tostring(text):lower():gmatch("%a+") do
        list[#list + 1] = word
    end
    for i, word in ipairs(list) do
        if word ~= npcName then
            local entry = #word >= 5 and lookup[norm(word)] or nil
            if not entry and list[i + 1] then
                entry = lookup[norm(word .. list[i + 1])]
            end
            if entry then
                return entry
            end
        end
    end
    return nil
end

local function itemSearchWords(entry)
    local words = {entry.key:lower()}
    for _, field in ipairs({"displayName", "name", "label"}) do
        local value = rawget(entry.def, field)
        if type(value) == "string" and value ~= "" and norm(value) ~= norm(entry.key) then
            words[#words + 1] = value:lower()
        end
    end
    return words
end

local function findItemById(key)
    local wanted = norm(key)
    for _, item in ipairs(inventoryItems()) do
        if norm(item.id) == wanted or norm(item.key) == wanted then
            return item
        end
    end
    return nil
end

local function countItem(itemId)
    local wanted = norm(itemId)
    local total = 0
    for _, item in ipairs(inventoryItems()) do
        if norm(item.id) == wanted then
            total = total + 1
        end
    end
    return total
end

local function equippedId()
    if not InventoryController then
        return nil
    end
    local ok, value = pcall(InventoryController.GetEquipped, InventoryController)
    return ok and value or nil
end

local function equipId(id)
    if not InventoryController then
        return false
    end
    if equippedId() == id then
        return true
    end
    pcall(InventoryController.Equip, InventoryController, id)
    task.wait(0.8)
    return equippedId() == id
end

local function equipItem(item)
    if InventoryController then
        local ok = equipId(item.key)
        log("equip " .. tostring(item.id) .. " -> " .. tostring(ok))
        return ok
    end
    local module = item.module
    local counter = module and rawget(module, "Seq")
    local seq = type(counter) == "number" and counter + 1 or item.seq
    if not seq then
        warnOnce("seq:" .. tostring(item.id), "Seq desconhecido para " .. tostring(item.id))
        return false
    end
    local remote = Remotes:FindFirstChild("Inventory")
    if not remote then
        return false
    end
    local ok = pcall(remote.FireServer, remote, "equipItem", {itemId = item.id, itemType = item.itemType, seq = seq})
    if ok and type(counter) == "number" then
        pcall(rawset, module, "Seq", seq)
    end
    log("equipItem " .. tostring(item.id) .. " seq=" .. tostring(seq) .. " -> " .. tostring(ok))
    task.wait(1)
    return ok
end

local poolCache
local poolItems

local function loadPools()
    if poolCache then
        return
    end
    poolCache = {}
    poolItems = {}
    local dataRoot = findPath(ReplicatedStorage, "Shared", "Data")
    if not dataRoot then
        return
    end
    for _, inst in ipairs(dataRoot:GetDescendants()) do
        if inst:IsA("ModuleScript") and inst.Name == "ItemPools" then
            local ok, module = pcall(require, inst)
            if ok and type(module) == "table" then
                for poolName, pool in pairs(module) do
                    if type(pool) == "table" and type(pool.items) == "table" then
                        local name = tostring(poolName)
                        poolItems[name] = {}
                        for id in pairs(pool.items) do
                            local key = norm(id)
                            poolCache[key] = poolCache[key] or {}
                            table.insert(poolCache[key], name)
                            table.insert(poolItems[name], tostring(id))
                        end
                        table.sort(poolItems[name])
                    end
                end
            end
            break
        end
    end
end

local function poolsFor(itemId)
    loadPools()
    local list = poolCache[norm(itemId)] or {}
    table.sort(list)
    return list
end

local function resolvePools(itemId, text)
    local pools = {}
    if itemId then
        for _, name in ipairs(poolsFor(itemId)) do
            pools[#pools + 1] = name
        end
    end
    if #pools == 0 and text then
        loadPools()
        local flatText = flat(text)
        for name in pairs(poolItems) do
            if #name >= 5 and flatText:find(flat(name), 1, true) then
                pools[#pools + 1] = name
            end
        end
        table.sort(pools)
    end
    return pools
end

local function noteFishing(itemId, text)
    state.fishWanted = true
    local pools = resolvePools(itemId, text)
    if #pools > 0 then
        warnOnce("pool:" .. tostring(itemId or text), "Item " .. tostring(itemId or "objetivo") .. " sai nas pools: " .. table.concat(pools, ",") .. " | local atual: " .. tostring(currentArea()))
        for _, pool in ipairs(pools) do
            state.fishPools[#state.fishPools + 1] = pool
        end
    end
end

local function isBuyText(text)
    local lower = tostring(text):lower()
    return lower:find("%f[%a]buy%f[%A]") ~= nil or lower:find("%f[%a]purchase%f[%A]") ~= nil
end

local function describeNpcActions(npcId)
    local module = npcModules[npcId]
    if not module then
        return "sem modulo"
    end
    local parts = {}
    for nodeName, node in pairs(module.nodes) do
        if type(node) == "table" and type(node.serverActions) == "table" then
            for _, action in ipairs(node.serverActions) do
                if type(action) == "table" then
                    local detail = {}
                    for k, v in pairs(action) do
                        if type(v) == "string" or type(v) == "number" then
                            detail[#detail + 1] = tostring(k) .. "=" .. tostring(v)
                        end
                    end
                    table.sort(detail)
                    parts[#parts + 1] = tostring(nodeName) .. "{" .. table.concat(detail, ",") .. "}"
                end
            end
        end
    end
    table.sort(parts)
    return string.sub(table.concat(parts, " ; "), 1, 1500)
end

local function buyCandidates(entry, npcId)
    local list = {}
    local seen = {}
    local function add(npc, node, kind)
        local ref = npc .. ":" .. node
        if not seen[ref] then
            seen[ref] = true
            list[#list + 1] = {npc = npc, node = node, kind = kind}
        end
    end
    for _, ref in ipairs(index.refs[entry.key] or {}) do
        local kind = tostring(ref.kind):lower()
        if (not npcId or ref.npc == npcId) and not kind:find("quest", 1, true) then
            add(ref.npc, ref.node, ref.kind)
        end
    end
    local module = npcId and npcModules[npcId]
    if module then
        for nodeName, node in pairs(module.nodes) do
            if type(node) == "table" and type(node.serverActions) == "table" then
                for _, action in ipairs(node.serverActions) do
                    local kind = type(action) == "table" and tostring(action.type):lower() or ""
                    if not kind:find("quest", 1, true) and (kind:find("buy", 1, true) or kind:find("shop", 1, true) or kind:find("purchase", 1, true) or kind:find("vendor", 1, true)) then
                        add(npcId, nodeName, action.type)
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b)
        return a.npc .. a.node < b.npc .. b.node
    end)
    return list
end

local function buyItem(key, entry, text, npc)
    local seller = npcFromText(text) or npc
    local buyKey = "buy:" .. key
    if (state.retryAt[buyKey] or 0) > os.clock() then
        return false, "missing"
    end
    local used = state.attempts[buyKey] or 0
    if used >= 3 then
        state.attempts[buyKey] = 0
        state.retryAt[buyKey] = os.clock() + 600
        warnOnce("buy:limit:" .. key, "Compra de " .. entry.key .. " falhou 3 vezes em " .. tostring(seller) .. ", nova tentativa em 600s")
        return false, "missing"
    end
    local list = buyCandidates(entry, seller)
    if #list == 0 then
        state.retryAt[buyKey] = os.clock() + 600
        warnOnce("buy:none:" .. key, "Nenhum node de compra de " .. entry.key .. " em " .. tostring(seller) .. " | acoes: " .. describeNpcActions(tostring(seller)))
        return false, "missing"
    end
    state.attempts[buyKey] = used + 1
    state.retryAt[buyKey] = os.clock() + 8
    local choice = list[(used % #list) + 1]
    log("Comprando " .. entry.key .. " via " .. choice.npc .. ":" .. choice.node .. " (" .. tostring(choice.kind) .. ") tentativa " .. (used + 1))
    actOnNode(choice.npc, choice.node)
    task.wait(1.5)
    local bought = findItemById(entry.key)
    if bought then
        state.attempts[buyKey] = 0
        equipItem(bought)
        return true
    end
    return false, "missing"
end

local function prepareItem(key, text, npc)
    local entry = itemFromText(text, npc)
    if not entry then
        return true
    end
    local item = findItemById(entry.key)
    if item then
        local equipKey = "equip:" .. key
        if not state.attempts[equipKey] then
            state.attempts[equipKey] = 1
            log("Item " .. entry.key .. " achado no inventario")
            equipItem(item)
        end
        return true
    end
    local words = itemSearchWords(entry)
    if rawget(entry.def, "itemType") == "scroom" then
        warnOnce("catch:" .. entry.key, "Item " .. entry.key .. " e um scroom, precisa pescar")
        noteFishing(entry.key)
        return false, "fish"
    end
    if isBuyText(text) then
        return buyItem(key, entry, text, npc)
    end
    local itemKey = "item:" .. key
    local rescanKey = "rescan:" .. key
    local used = state.attempts[itemKey] or 0
    if used >= 3 then
        if (state.retryAt[rescanKey] or 0) > os.clock() then
            warnOnce("limit:" .. itemKey, "Item " .. entry.key .. " nao esta no mapa, quest adiada")
            return false, "missing"
        end
        used = 0
        state.attempts[itemKey] = 0
    end
    local scanKey = "scan:" .. key
    if (state.retryAt[scanKey] or 0) <= os.clock() then
        state.retryAt[scanKey] = os.clock() + 5
        state.attempts[itemKey] = used + 1
        if used + 1 >= 3 then
            state.retryAt[rescanKey] = os.clock() + 300
        end
        local target = objectFromText(table.concat(words, " ")) or findWorldItem(words)
        if not target and used >= 1 then
            target = searchItem(words)
        end
        if target then
            log("Item " .. entry.key .. " fora do inventario, coletando " .. target:GetFullName())
            collectObjects(target)
            task.wait(1.5)
            local collected = findItemById(entry.key)
            if collected then
                equipItem(collected)
                return true
            end
        end
    end
    return false, "missing"
end

-- // HUD de quests
local function hudTexts(id)
    local list, checks = {}, {}
    local frame = Tracked and Tracked.Cached and Tracked.Cached[id]
    local content = typeof(frame) == "Instance" and frame:FindFirstChild("Content")
    if not content then
        return list, checks
    end
    for _, child in ipairs(content:GetChildren()) do
        local number = tonumber(child.Name:match("^Objective(%d+)$"))
        if number then
            local description = child:FindFirstChild("Description")
            if description and (description:IsA("TextLabel") or description:IsA("TextButton")) then
                list[number] = description.Text
            end
            local check = child:FindFirstChild("Check")
            local mark = check and check:FindFirstChildWhichIsA("ImageLabel")
            if mark then
                checks[number] = mark.Visible
            end
        end
    end
    return list, checks
end

local function counterDone(text)
    local a, b = tostring(text):match("%((%d+)/(%d+)%)")
    if a and b then
        return tonumber(a) >= tonumber(b)
    end
    return nil
end

local function objectiveDone(def, texts, checks, i)
    if checks and checks[i] ~= nil then
        return checks[i]
    end
    local objectives = def.objectives or {}
    if objectives[i] and objectives[i].type ~= "give" then
        local own = counterDone(texts[i] or objectives[i].display or "")
        if own ~= nil then
            return own
        end
    end
    for j = i + 1, #objectives do
        if counterDone(texts[j] or objectives[j].display or "") == true then
            return true
        end
    end
    return false
end

local function describe(id, def, texts)
    local lines = {
        "Missao " .. id .. " | " .. tostring(def.displayName) .. " | " .. tostring(def.questType) .. " | giver=" .. tostring(def.giver)
    }
    for i, obj in ipairs(def.objectives or {}) do
        lines[#lines + 1] = "  " .. i .. ": " .. tostring(obj.type) .. " | " .. clean(texts[i] or obj.display)
    end
    return table.concat(lines, "\n")
end

-- // Pesca automatica
local fishSet, fishShutdown, fishKind

do
    local fish: any = {running = false, gen = 0, ready = false}

    local function fishCloseRing()
        local ring = fish.ring
        fish.ring = nil
        if not ring then
            return
        end
        local ui = rawget(ring, "_ui")
        pcall(function()
            ring:Destroy()
        end)
        if typeof(ui) == "Instance" and ui.Parent then
            pcall(ui.Destroy, ui)
        end
    end

    local function fishDriveTune(object)
        local connection
        connection = RunService.RenderStepped:Connect(function()
            if not fish.running or not object._jan then
                connection:Disconnect()
                return
            end
            local target = object._target
            if target then
                object._needleX = target
                object._needleVel = 0
            end
        end)
    end

    local function fishDriveMain(object)
        local zone = object._zone
        local item = object._item
        if not (zone and item) then
            return
        end
        local pinned = pcall(object.PinZone, object, 1000000)
        local misses = 0
        local connection
        connection = RunService.RenderStepped:Connect(function()
            if not fish.running or not object._jan then
                connection:Disconnect()
                return
            end
            local moved = pcall(function()
                zone:MoveTo(item:GetPos())
            end)
            if moved and pinned then
                local checked, inside = pcall(function()
                    local low, high = zone:GetBounds()
                    local position = item:GetPos()
                    return low <= position and position <= high
                end)
                if checked and not inside then
                    misses = misses + 1
                    if misses >= 5 then
                        pinned = false
                        pcall(zone.SetPinned, zone, false)
                    end
                else
                    misses = 0
                end
            end
        end)
    end

    local function fishTryFinish(object)
        local limit = 1
        for k, v in pairs(object) do
            if type(k) == "string" and type(v) == "number" then
                local lower = k:lower()
                if lower:find("max", 1, true) and lower:find("progress", 1, true) then
                    limit = v
                end
            end
        end
        for k, v in pairs(object) do
            if type(k) == "string" and type(v) == "number" and k:lower():find("progress", 1, true) then
                if not k:lower():find("max", 1, true) then
                    object[k] = limit
                end
            end
        end
        for _, name in ipairs({"Win", "Finish", "Complete", "Succeed", "_win", "_finish", "_complete", "_succeed"}) do
            local okGet, fn = pcall(function()
                return object[name]
            end)
            if okGet and type(fn) == "function" then
                pcall(fn, object)
                break
            end
        end
    end

    local function fishPrecision()
        if state.fishPerfect then
            return 0.996 + math.random() * 0.003
        end
        return 0.985 + math.random() * 0.014
    end

    local function fishInit()
        if fish.ready then
            return true
        end
        if not (InventoryController and MinigameController and MinigameController.StageChanged) then
            warnOnce("fish:init", "Controllers de pesca nao encontrados")
            return false
        end
        local cast = findPath(LocalPlayer:FindFirstChild("PlayerGui"), "Input", "InputContext", "Cast")
        local remote = Remotes:FindFirstChild("Minigame")
        if not (cast and remote) then
            warnOnce("fish:ui", "Botao de pesca ou remote Minigame nao encontrado")
            return false
        end
        fish.cast = cast
        fish.remote = remote
        fish.original = MinigameController._displayRing
        fish.hook = function(self, ...)
            if not fish.running then
                return fish.original(self, ...)
            end
            fish.castAt = os.clock()
            fish.fired = false
            fish.ring = nil
            local precision = fishPrecision()
            task.delay(0.3 + math.random() * 0.3, function()
                pcall(remote.FireServer, remote, "startSession", precision)
                fish.fired = true
                task.delay(0.15, fishCloseRing)
            end)
            return nil
        end
        MinigameController._displayRing = fish.hook
        state.connections[#state.connections + 1] = MinigameController.StageChanged:Connect(function(stage, object)
            if not fish.running or not object then
                return
            end
            if stage == "ring" then
                fish.ring = object
                if fish.fired then
                    task.delay(0.15, fishCloseRing)
                end
            elseif stage == "tune" then
                fishDriveTune(object)
            elseif stage == "main" then
                fishDriveMain(object)
                if env.AutoCastInstant ~= false then
                    task.defer(function()
                        pcall(fishTryFinish, object)
                    end)
                end
            end
        end)
        if MinigameController.Caught then
            state.connections[#state.connections + 1] = MinigameController.Caught:Connect(function(data)
                if fish.running and type(data) == "table" then
                    state.fishCaught = (state.fishCaught or 0) + 1
                    state.caughtIds[norm(data.itemId)] = true
                    log("Pescou " .. tostring(data.itemId) .. " total=" .. state.fishCaught)
                end
            end)
        end
        fish.ready = true
        return true
    end

    local function fishWait(condition, timeout)
        local started = os.clock()
        while fish.running and os.clock() - started < timeout do
            local value = condition()
            if value then
                return value
            end
            task.wait(0.05)
        end
        return nil
    end

    local function fishCycle()
        local controller = MinigameController
        if controller.InSession then
            fishWait(function()
                return not controller.InSession
            end, 90)
            task.wait(0.8)
            return
        end
        if next(controller.CastBlocks) then
            task.wait(1)
            return
        end
        local remaining = (controller._readyAt or 0) - os.clock()
        if remaining > 0 then
            task.wait(remaining + 0.05)
        end
        if equippedId() ~= "instrument" then
            pcall(InventoryController.Equip, InventoryController, "instrument")
            task.wait(0.8)
            if equippedId() ~= "instrument" then
                task.wait(2)
                return
            end
        end
        fish.castAt = nil
        local pressed = pcall(function()
            fish.cast:Fire(true)
            task.wait(0.05)
            fish.cast:Fire(false)
        end)
        if not pressed then
            task.wait(3)
            return
        end
        local function refresh()
            pcall(InventoryController.Equip, InventoryController, nil)
            task.wait(0.1)
            pcall(InventoryController.Equip, InventoryController, "instrument")
            task.wait(0.8)
        end
        if not fishWait(function()
            return fish.castAt
        end, 2) then
            refresh()
            return
        end
        if not fishWait(function()
            return controller.InSession
        end, 6) then
            refresh()
            return
        end
        fishWait(function()
            return not controller.InSession
        end, 90)
        fishCloseRing()
        task.wait(0.8 + math.random() * 0.3)
    end

    fishSet = function(on)
        if on then
            if fish.running then
                return
            end
            if env.AutoCastState and env.AutoCastState.active then
                warnOnce("fish:external", "AutoCast externo ja esta ativo, usando ele")
                return
            end
            if not fishInit() then
                return
            end
            fish.running = true
            state.fishQuiet = true
            fish.gen = fish.gen + 1
            local gen = fish.gen
            logEvery("fish:on", 60, "Pesca automatica ligada perfect=" .. tostring(state.fishPerfect == true))
            task.spawn(function()
                while fish.running and fish.gen == gen and state.active do
                    local ok = pcall(fishCycle)
                    if not ok then
                        task.wait(2)
                    end
                    task.wait(0.2)
                end
                fishCloseRing()
            end)
        elseif fish.running then
            fish.running = false
            state.fishQuiet = false
            logEvery("fish:off", 60, "Pesca automatica desligada")
        end
    end

    fishShutdown = function()
        fish.running = false
        if fish.ready and MinigameController and MinigameController._displayRing == fish.hook then
            MinigameController._displayRing = fish.original
        end
    end

    fishPause = function()
        if fish.running then
            fish.running = false
            state.fishQuiet = false
            logEvery("fish:pause", 60, "Pesca automatica pausada")
        end
        local waited = 0
        while MinigameController and MinigameController.InSession and waited < 20 do
            task.wait(0.25)
            waited = waited + 0.25
        end
    end

    fishKind = function(obj, lower)
        local path = type(obj.path) == "table" and obj.path or {}
        local first = tostring(path[1] or ""):lower()
        local last = tostring(path[#path] or ""):lower()
        if last:find("perfect", 1, true) or lower:find("perfect", 1, true) then
            return "perfect"
        end
        if lower:find("catch", 1, true) or lower:find("fish", 1, true) or last:find("catch", 1, true) or last:find("caught", 1, true) then
            return "catch"
        end
        if first == "leveling" or lower:find("level", 1, true) then
            return "level"
        end
        return nil
    end
end

-- // Ocarina
local playSongsHandler, bloomcallHandler

do
    local ocarinaWindow = load("Client", "UI", "Windows", "Ocarina")
    local songPriority = {"blooming", "passage", "unveiling", "exp1", "luck1", "homeward"}
    local songBlocked = {maestro = true, blessing = true}
    local songFallback = {"blooming", "passage", "unveiling", "homeward"}
    local ocarinaSkipWords = {"hotbar", "inventory", "backpack", "slot"}
    local ocarinaTargetList = {}
    local ocarinaRefreshedAt = 0

    local function ocarinaExcluded(inst)
        local node = inst.Parent
        while node and node ~= game do
            local name = norm(node.Name)
            for _, word in ipairs(ocarinaSkipWords) do
                if name:find(word, 1, true) then
                    return true
                end
            end
            node = node.Parent
        end
        return false
    end

    local function ocarinaTargets()
        local list = {}
        local seen = {}
        local function add(inst)
            if typeof(inst) == "Instance" and not seen[inst] then
                seen[inst] = true
                list[#list + 1] = inst
            end
        end
        if type(ocarinaWindow) == "table" then
            for _, field in ipairs({"_ui", "_frame", "_gui", "_window", "_root", "_main"}) do
                add(rawget(ocarinaWindow, field))
            end
        end
        local gui = LocalPlayer:FindFirstChild("PlayerGui")
        if gui then
            for _, inst in ipairs(gui:GetDescendants()) do
                if norm(inst.Name) == "ocarina" and (inst:IsA("ScreenGui") or inst:IsA("Frame") or inst:IsA("CanvasGroup")) and not ocarinaExcluded(inst) then
                    add(inst)
                end
            end
        end
        return list
    end

    local function ocarinaHideStep()
        for _, inst in ipairs(ocarinaTargetList) do
            if inst.Parent then
                if inst:IsA("ScreenGui") then
                    if inst.Enabled then
                        inst.Enabled = false
                    end
                elseif inst:IsA("GuiObject") and inst.Visible then
                    inst.Visible = false
                end
            end
        end
    end

    local function ocarinaQuiet(seconds)
        state.ocarinaUntil = math.max(state.ocarinaUntil or 0, os.clock() + seconds)
    end

    state.connections[#state.connections + 1] = RunService.RenderStepped:Connect(function()
        if not state.active or env.QuestHideOcarina == false then
            return
        end
        local now = os.clock()
        if now >= (state.ocarinaUntil or 0) then
            ocarinaRefreshedAt = 0
            return
        end
        if now - ocarinaRefreshedAt > 1 then
            ocarinaRefreshedAt = now
            ocarinaTargetList = ocarinaTargets()
        end
        ocarinaHideStep()
    end)

    local function knownSongIds()
        local ids = {}
        local frames = type(ocarinaWindow) == "table" and rawget(ocarinaWindow, "_songFrames")
        local known = type(frames) == "table" and frames.Known
        if type(known) ~= "table" then
            return ids
        end
        local present = {}
        for id in pairs(known) do
            present[tostring(id)] = true
        end
        for _, id in ipairs(songPriority) do
            if present[id] then
                ids[#ids + 1] = id
                present[id] = nil
            end
        end
        local rest = {}
        for id in pairs(present) do
            if not songBlocked[id] then
                rest[#rest + 1] = id
            end
        end
        table.sort(rest)
        for _, id in ipairs(rest) do
            ids[#ids + 1] = id
        end
        return ids
    end

    local function songList(only)
        local ids = only
        if not ids and type(env.QuestSongs) == "table" and #env.QuestSongs > 0 then
            ids = env.QuestSongs
        end
        if not ids then
            ids = knownSongIds()
        end
        if #ids == 0 then
            ids = songFallback
        end
        return ids
    end

    local function ocarinaSignature(id, i)
        local texts, checks = hudTexts(id)
        return tostring(texts[i]) .. "|" .. tostring(checks[i])
    end

    local function ocarinaEquip()
        ocarinaQuiet(8)
        fishPause()
        equipId("ocarina")
        local ready = equippedId() == "ocarina"
        if not ready then
            warnOnce("ocarina:equip:" .. tostring(equippedId()), "Ocarina nao ficou equipada, equipado agora: " .. tostring(equippedId()))
        end
        return ready
    end

    local function ocarinaFire(remote, song)
        ocarinaQuiet(6)
        pcall(remote.FireServer, remote, song)
    end

    local function ocarinaPlay(remote, id, i, song)
        local beforeSignature = ocarinaSignature(id, i)
        local beforeEvents = state.ocarinaLocal or 0
        ocarinaFire(remote, song)
        local waited = 0
        while waited < 3 do
            task.wait(0.25)
            waited = waited + 0.25
            if (state.ocarinaLocal or 0) ~= beforeEvents or ocarinaSignature(id, i) ~= beforeSignature then
                return true
            end
        end
        return false
    end

    local function gardenPosition()
        if state.gardenPos then
            return state.gardenPos
        end
        local anchor = state.npcPositions.elanor_sg
        local best, bestDistance
        for _, inst in ipairs(Workspace:GetDescendants()) do
            if inst:IsA("Model") or inst:IsA("BasePart") then
                local flatName = norm(inst.Name)
                if (flatName:find("garden", 1, true) or flatName:find("bloomsite", 1, true)) and not flatName:find("under", 1, true) then
                    local position = pivotPosition(inst)
                    if position then
                        local distance = anchor and (position - anchor).Magnitude or 0
                        if not bestDistance or distance < bestDistance then
                            best, bestDistance = position, distance
                        end
                    end
                end
            end
        end
        state.gardenPos = best
        return best or anchor
    end

    playSongsHandler = function(id, obj, i)
        local key = "songs:" .. id
        if (state.retryAt[key] or 0) > os.clock() then
            return "skip"
        end
        local remote = Remotes:FindFirstChild("Ocarina")
        if not remote then
            warnOnce("ocarina:remote", "Remote Ocarina nao encontrado")
            return "skip"
        end
        ocarinaEquip()
        local songs = songList()
        local plays = 0
        local fails = 0
        while state.active and plays < 8 and fails < #songs do
            local texts = hudTexts(id)
            if counterDone(texts[i] or obj.display or "") == true then
                break
            end
            local song = songs[(plays % #songs) + 1]
            local moved = ocarinaPlay(remote, id, i, song)
            plays = plays + 1
            fails = moved and 0 or fails + 1
            log("Ocarina FireServer " .. song .. " -> " .. tostring(moved))
        end
        if fails >= #songs then
            state.retryAt[key] = os.clock() + 300
            warnOnce("songs:fail:" .. id, "Nenhuma musica contou em " .. id .. ", tentando de novo em 300s")
            return "skip"
        end
        return plays > 0
    end

    bloomcallHandler = function(id, obj, i)
        local key = "bloomcall"
        local used = state.attempts[key] or 0
        if used >= (tonumber(env.QuestAutoAttempts) or 4) then
            warnOnce("limit:" .. key, "Tentativas esgotadas em Bloomcall")
            return "skip"
        end
        if (state.retryAt[key] or 0) > os.clock() then
            state.cooling = true
            return false
        end
        state.retryAt[key] = os.clock() + 20
        state.attempts[key] = used + 1
        local remote = Remotes:FindFirstChild("Ocarina")
        if not remote then
            warnOnce("ocarina:remote", "Remote Ocarina nao encontrado")
            return "skip"
        end
        local anchor = state.npcPositions.elanor_sg
        if anchor then
            streamAt(anchor)
            task.wait(1.5)
        end
        local target = gardenPosition()
        if not target then
            warnOnce("garden:none", "Jardim da Elanor nao encontrado")
            return false
        end
        noclipOn()
        local arrived = flyTo(target + hoverOffset())
        noclipOff()
        log("Bloomcall tentativa " .. (used + 1) .. " voo=" .. tostring(arrived) .. " @ " .. tostring(target))
        if not arrived then
            return false
        end
        ocarinaEquip()
        ocarinaFire(remote, "blooming")
        task.wait(2)
        log("Bloomcall FireServer blooming")
        return true
    end
end

-- // Corrida da Shax
local raceObjectiveMatch, finishShaxRace

do
    local function raceIsRunning()
        local raceState = state.raceState
        return type(raceState) == "table" and raceState.running == true
    end

    raceObjectiveMatch = function(lower, obj, id)
        if lower:find("%f[%a]race%f[%A]") ~= nil or lower:find("%f[%a]racing%f[%A]") ~= nil or lower:find("%f[%a]track%f[%A]") ~= nil then
            return true
        end
        if type(obj) ~= "table" or obj.type ~= "dataFlag" then
            return false
        end
        if obj.npc == RACE_NPC_ID then
            return true
        end
        return type(id) == "string" and id:find("^shax_race") ~= nil
    end

    local raceData

    local function raceInfo(id)
        if raceData == nil then
            raceData = load("Shared", "Data", "ShaxRaces") or false
            if not raceData then
                local dataRoot = findPath(ReplicatedStorage, "Shared", "Data")
                local inst = dataRoot and dataRoot:FindFirstChild("ShaxRaces", true)
                if inst then
                    local ok, module = pcall(require, inst)
                    raceData = ok and type(module) == "table" and module or false
                end
            end
        end
        if type(raceData) ~= "table" then
            return nil
        end
        local raceState = state.raceState
        local current = type(raceState) == "table" and raceState.race
        return raceData[current or ""] or raceData[id]
    end

    local function raceCandidates(id)
        local keys = {id}
        local raceState = state.raceState
        if type(raceState) == "table" and raceState.race then
            keys[#keys + 1] = tostring(raceState.race)
        end
        local list = {}
        local seen = {}
        local recorded = type(env.QuestDialogueRecorded) == "table" and env.QuestDialogueRecorded or {}
        for ref in pairs(recorded) do
            local npc, node = tostring(ref):match("^(.-):(.+)$")
            if npc and node and node:lower():find("race", 1, true) and not seen[ref] then
                seen[ref] = true
                list[#list + 1] = {npc = npc, node = node, kind = "recorded"}
            end
        end
        for _, key in ipairs(keys) do
            for _, entry in ipairs(index.refs[key] or {}) do
                local ref = entry.npc .. ":" .. entry.node
                if not seen[ref] and entry.kind ~= "acceptQuest" and entry.kind ~= "completeQuest" then
                    seen[ref] = true
                    list[#list + 1] = entry
                end
            end
        end
        local function rank(entry)
            local kind = tostring(entry.kind):lower()
            if kind == "recorded" then
                return -1
            end
            if kind:find("race", 1, true) then
                return 0
            end
            if kind == "setdata" then
                return 2
            end
            return 1
        end
        table.sort(list, function(a, b)
            local rankA, rankB = rank(a), rank(b)
            if rankA ~= rankB then
                return rankA < rankB
            end
            return a.npc .. a.node < b.npc .. b.node
        end)
        return list
    end

    local function raceWaitRunning(seconds)
        local waited = 0
        while state.active and waited < seconds and not raceIsRunning() do
            task.wait(0.25)
            waited = waited + 0.25
        end
        return raceIsRunning()
    end

    local function raceStart(id)
        if env.QuestAutoRaceStart == false then
            warnOnce("shaxrace:idle", "ShaxRace sem corrida ativa, inicio automatico desligado")
            return "skip"
        end
        local key = "shaxrace:start:" .. tostring(id)
        local used = state.attempts[key] or 0
        if used >= (tonumber(env.QuestAutoAttempts) or 4) then
            warnOnce("limit:" .. key, "Tentativas esgotadas em ShaxRace start " .. tostring(id))
            return "skip"
        end
        if (state.retryAt[key] or 0) > os.clock() then
            state.cooling = true
            return false
        end
        state.retryAt[key] = os.clock() + 20
        state.attempts[key] = used + 1
        local info = raceInfo(id)
        local list = raceCandidates(id)
        if #list > 0 then
            local choice = list[(used % #list) + 1]
            log("ShaxRace start tentativa " .. (used + 1) .. " via " .. choice.npc .. ":" .. choice.node .. " (" .. tostring(choice.kind) .. ")")
            actOnNode(choice.npc, choice.node)
        else
            local npc = (used % 2 == 0 or not info) and RACE_NPC_ID or info.npc
            log("ShaxRace start tentativa " .. (used + 1) .. " conversando com " .. tostring(npc))
            talkToNpc(npc)
        end
        local running = raceWaitRunning(6)
        log("ShaxRace start -> running=" .. tostring(running))
        return running and true or false
    end

    local function raceFinishPosition(info)
        local model = info and info.model
        if not model then
            return nil
        end
        local track = Workspace:FindFirstChild(model, true)
        if not track then
            return nil
        end
        local parts = {}
        for _, inst in ipairs(track:GetDescendants()) do
            if inst:IsA("BasePart") then
                local name = norm(inst.Name)
                if name:find("finish", 1, true) or name:find("goal", 1, true) or name:find("arriv", 1, true) then
                    return inst.Position
                end
                parts[#parts + 1] = inst
            end
        end
        local root = getRoot()
        local origin = root and root.Position
        if not origin then
            return nil
        end
        local far, farDistance
        for _, part in ipairs(parts) do
            local distance = (part.Position - origin).Magnitude
            if not farDistance or distance > farDistance then
                far, farDistance = part.Position, distance
            end
        end
        if far then
            warnOnce("shaxrace:farpart", "Chegada sem nome reconhecido, usando a parte mais distante do modelo " .. tostring(model))
        end
        return far
    end

    local function raceFly(info)
        local target
        local tries = 0
        while state.active and not target and tries < 6 do
            target = raceFinishPosition(info)
            if not target then
                tries = tries + 1
                task.wait(0.5)
            end
        end
        if not target then
            warnOnce("shaxrace:finishpos", "Linha de chegada da corrida nao encontrada")
            return false
        end
        streamAt(target)
        local limit
        local root = getRoot()
        if root then
            local minTime = info and tonumber(info.minTime) or 7
            local remaining = (state.raceStartedAt or os.clock()) + minTime + 1.5 - os.clock()
            if remaining > 0 then
                limit = math.min(speed(), math.max(5, (target - root.Position).Magnitude / remaining))
            end
        end
        noclipOn()
        local arrived = flyTo(target + hoverOffset(), limit)
        noclipOff()
        log("ShaxRace chegada voo=" .. tostring(arrived) .. " @ " .. tostring(target))
        return arrived
    end

    finishShaxRace = function(id)
        local remote = Remotes:FindFirstChild("ShaxRace")
        if not remote then
            warnOnce("shaxrace:remote", "Remote ShaxRace nao encontrado")
            return "skip"
        end
        if not raceIsRunning() then
            local started = raceStart(id)
            if started ~= true then
                return started
            end
        end
        local key = "shaxrace:finish:" .. tostring(id)
        local used = state.attempts[key] or 0
        if used >= (tonumber(env.QuestAutoAttempts) or 4) then
            warnOnce("limit:" .. key, "Tentativas esgotadas em ShaxRace finish")
            return "skip"
        end
        if (state.retryAt[key] or 0) > os.clock() then
            state.cooling = true
            return false
        end
        state.retryAt[key] = os.clock() + 20
        state.attempts[key] = used + 1
        local info = raceInfo(id)
        log("ShaxRace finish tentativa " .. (used + 1))
        if env.QuestAutoFly ~= false then
            raceFly(info)
        end
        local minTime = info and tonumber(info.minTime) or 7
        local remaining = (state.raceStartedAt or os.clock()) + minTime + 1 - os.clock()
        if remaining > 0 then
            task.wait(remaining)
        end
        local waited = 0
        while state.active and raceIsRunning() and waited < 3 do
            task.wait(0.25)
            waited = waited + 0.25
        end
        if not raceIsRunning() then
            log("ShaxRace terminou na chegada")
            return true
        end
        local ok = pcall(remote.FireServer, remote, "finish")
        log("ShaxRace finish -> " .. tostring(ok))
        task.wait(2)
        return ok
    end
end

-- // Exploracao
local worldWords, exploreHandler

do
    local exploreStop = {speak = true, ["return"] = true, there = true, where = true}

    local function exploreWords(text)
        local words = {}
        local seen = {}
        for word in tostring(text):lower():gmatch("%a+") do
            if #word >= 5 and not exploreStop[word] and not seen[word] then
                seen[word] = true
                words[#words + 1] = word
                if word:sub(-1) == "s" then
                    local single = word:sub(1, -2)
                    if not seen[single] then
                        seen[single] = true
                        words[#words + 1] = single
                    end
                end
            end
        end
        return words
    end

    local worldStop = {
        ["from"] = true, ["with"] = true, ["that"] = true, ["this"] = true, ["then"] = true, ["them"] = true,
        ["they"] = true, ["into"] = true, ["back"] = true, ["give"] = true, ["take"] = true, ["bring"] = true,
        ["find"] = true, ["speak"] = true, ["talk"] = true, ["return"] = true, ["there"] = true, ["where"] = true,
        ["your"] = true, ["some"] = true, ["have"] = true, ["will"] = true, ["when"] = true, ["what"] = true,
        ["near"] = true, ["once"] = true,
    }

    worldWords = function(text)
        local words = {}
        local seen = {}
        local cleaned = clean(tostring(text):lower())
        for word in cleaned:gmatch("%a+") do
            if #word >= 4 and not worldStop[word] then
                local stem = word
                if #word >= 5 and word:sub(-1) == "s" and word:sub(-2) ~= "ss" then
                    stem = word:sub(1, -2)
                end
                if not seen[stem] then
                    seen[stem] = true
                    words[#words + 1] = stem
                end
            end
        end
        return words
    end

    exploreHandler = function(id, obj, i)
        local key = "explore:" .. id .. "#" .. i
        local used = state.attempts[key] or 0
        if used >= 3 then
            warnOnce("limit:" .. key, "Tentativas esgotadas em exploracao " .. key)
            return "skip"
        end
        if (state.retryAt[key] or 0) > os.clock() then
            state.cooling = true
            return false
        end
        state.retryAt[key] = os.clock() + 20
        state.attempts[key] = used + 1
        local words = exploreWords(obj.display or "")
        if #words == 0 then
            return "skip"
        end
        local target = findWorldItem(words)
        if not target and used >= 1 then
            target = searchItem(words)
        end
        local position = target and pivotPosition(target)
        if not position then
            warnOnce("explore:none:" .. key, "Destino nao encontrado para " .. table.concat(words, ","))
            return "skip"
        end
        log("Exploracao tentativa " .. (used + 1) .. " destino " .. target:GetFullName() .. " @ " .. tostring(position))
        streamAt(position)
        noclipOn()
        local arrived = flyTo(position + hoverOffset())
        noclipOff()
        log("Exploracao voo=" .. tostring(arrived))
        task.wait(2)
        return arrived
    end
end

-- // Handlers de objetivos
local handlers = {
    {pattern = "find your way into", run = exploreHandler},
    {pattern = "grove statues", run = collectStatues},
    {match = raceObjectiveMatch, run = finishShaxRace},
    {pattern = "songs on your ocarina", run = playSongsHandler},
    {pattern = "play bloomcall", run = bloomcallHandler},
}

if type(env.QuestAutoHandlers) == "table" then
    for _, extra in ipairs(env.QuestAutoHandlers) do
        handlers[#handlers + 1] = extra
    end
end

-- // Fila de quests
local function completedSet()
    local set = {}
    if QuestLog and type(QuestLog.Cached) == "table" then
        for id, info in pairs(QuestLog.Cached) do
            if type(info) == "table" and info.questType == "completed" then
                set[id] = true
            end
        end
    end
    return set
end

local function isMain(id)
    local def = Quests and Quests[id]
    return type(def) == "table" and def.questType == "main"
end

local function questLevel(def)
    if type(def) ~= "table" then
        return nil
    end
    for _, cond in ipairs(def.available or {}) do
        if cond.type == "level" then
            return tonumber(cond.value)
        end
    end
    return nil
end

local function levelFromText(inst)
    local text = clean(inst.Text)
    local value = text:match("^%s*[Ll][Vv][Ll]?%.?%s*(%d+)%s*$") or text:match("^%s*[Ll]evel%s*:?%s*(%d+)%s*$")
    if not value and inst.Name:lower():find("level", 1, true) then
        value = text:match("^%s*(%d+)%s*$")
    end
    return tonumber(value)
end

local function levelFromControllers()
    local controllers = okRegistry and Registry.C
    if type(controllers) ~= "table" then
        return nil
    end
    local names = {}
    local found
    for name, controller in pairs(controllers) do
        names[#names + 1] = tostring(name)
        if not found and type(controller) == "table" then
            for _, field in ipairs({"Level", "level", "CurrentLevel"}) do
                local value = rawget(controller, field)
                if type(value) == "number" then
                    found = value
                    break
                end
            end
            if not found then
                local okGet, value = pcall(function()
                    return controller:GetLevel()
                end)
                if okGet and type(value) == "number" then
                    found = value
                end
            end
        end
    end
    table.sort(names)
    warnOnce("registry:list", "Controllers do Registry: " .. table.concat(names, ","))
    return found
end

local function levelFromGui()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not gui then
        return nil
    end
    for _, inst in ipairs(gui:GetDescendants()) do
        if inst:IsA("TextLabel") and inst.Visible then
            local value = levelFromText(inst)
            if value and value > 0 and value < 1000 then
                return value
            end
        end
    end
    return nil
end

local function playerLevel()
    if os.clock() - (state.levelAt or -100) < 20 then
        return state.level
    end
    state.levelAt = os.clock()
    local found = levelFromControllers() or levelFromGui()
    if found ~= state.level then
        state.level = found
        log("Nivel detectado: " .. tostring(found))
    end
    if not found then
        warnOnce("level:none", "Nivel do jogador nao detectado, estimando pelas quests recusadas")
    end
    return found
end

local function mainFirst(ids)
    table.sort(ids, function(a, b)
        local mainA, mainB = isMain(a), isMain(b)
        if mainA ~= mainB then
            return mainA
        end
        local levelA = questLevel(Quests and Quests[a]) or 0
        local levelB = questLevel(Quests and Quests[b]) or 0
        if levelA ~= levelB then
            return levelA < levelB
        end
        return a < b
    end)
end

local function orderIds(ids)
    local fresh = {}
    for _, id in ipairs(ids) do
        if not state.order[id] then
            fresh[#fresh + 1] = id
        end
    end
    table.sort(fresh)
    for _, id in ipairs(fresh) do
        state.orderCount = state.orderCount + 1
        state.order[id] = state.orderCount
    end
    table.sort(ids, function(a, b)
        local mainA, mainB = isMain(a), isMain(b)
        if mainA ~= mainB then
            return mainA
        end
        return state.order[a] < state.order[b]
    end)
end

local function activeQuestIds()
    local seen = {}
    local ids = {}
    local completed = completedSet()
    if Tracked and type(Tracked.Cached) == "table" then
        for id in pairs(Tracked.Cached) do
            if not seen[id] then
                seen[id] = true
                ids[#ids + 1] = id
            end
        end
    end
    if QuestLog and type(QuestLog.Cached) == "table" then
        for id, info in pairs(QuestLog.Cached) do
            if type(info) == "table" and info.questType ~= "completed" and not seen[id] then
                seen[id] = true
                ids[#ids + 1] = id
            end
        end
    end
    for id, tracked in pairs(state.loadoutQuests) do
        if tracked and not seen[id] and not completed[id] and Quests and type(Quests[id]) == "table" then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    orderIds(ids)
    return ids, seen
end

local function registerMiss(key)
    state.misses[key] = (state.misses[key] or 0) + 1
    if state.misses[key] >= 3 then
        state.misses[key] = 0
        return true
    end
    return false
end

local function refCandidates(id, text)
    local list = index.refs[id]
    if not list then
        return nil
    end
    local wanted = npcFromText(text)
    local out = {}
    local seen = {}
    for _, entry in ipairs(list) do
        local key = entry.npc .. ":" .. entry.node
        if not seen[key] and entry.kind ~= "acceptQuest" and entry.kind ~= "completeQuest" and (not wanted or entry.npc == wanted) then
            seen[key] = true
            out[#out + 1] = entry
        end
    end
    return out
end

local function handInCandidates(id, text)
    local refs = refCandidates(id, text) or {}
    local list = {}
    for _, entry in ipairs(refs) do
        if entry.kind == "giveQuestItem" then
            list[#list + 1] = entry
        end
    end
    for _, entry in ipairs(index.complete[id] or {}) do
        list[#list + 1] = entry
    end
    for _, entry in ipairs(refs) do
        if entry.kind ~= "giveQuestItem" then
            list[#list + 1] = entry
        end
    end
    return list
end

local function refreshNeeds()
    local skip = type(env.QuestAutoSkip) == "table" and env.QuestAutoSkip or {}
    local ids = activeQuestIds()
    local needs = {}
    local poolSet = {}
    local fishAny = false
    local perfect = false
    for _, id in ipairs(ids) do
        local def = Quests and Quests[id]
        if not skip[id] and type(def) == "table" then
            local texts, checks = hudTexts(id)
            for i, obj in ipairs(def.objectives or {}) do
                if not objectiveDone(def, texts, checks, i) then
                    local text = obj.display or texts[i] or ""
                    local lower = tostring(text):lower()
                    local hudHave, hudCount = tostring(texts[i] or obj.display or ""):match("%((%d+)/(%d+)%)")
                    local need
                    if obj.type == "give" then
                        local count = tonumber(hudCount) or tonumber(obj.count) or 1
                        local have = tonumber(hudHave) or (obj.itemId and countItem(obj.itemId) or 0)
                        local ready = counterDone(texts[i] or obj.display or "")
                        if ready == nil then
                            ready = obj.itemId ~= nil and have >= count
                        end
                        if not ready then
                            local fishable = (obj.itemId ~= nil and #poolsFor(obj.itemId) > 0) or lower:find("catch", 1, true) ~= nil
                            need = {item = obj.itemId, have = have, count = count, fish = fishable, text = text}
                        end
                    elseif obj.type == "dataFlag" then
                        local entry = itemFromText(text)
                        if entry and not findItemById(entry.key) then
                            local scroom = rawget(entry.def, "itemType") == "scroom"
                            need = {item = entry.key, have = 0, count = 1, fish = scroom or #poolsFor(entry.key) > 0, text = text}
                        end
                    elseif obj.type == "count" then
                        local kind = fishKind(obj, lower)
                        if kind then
                            need = {have = tonumber(hudHave) or 0, count = tonumber(hudCount) or 1, fish = true, text = text, perfect = kind == "perfect", counter = true}
                        end
                    end
                    if need then
                        need.quest = id
                        need.index = i
                        needs[id .. "#" .. i] = need
                        if need.fish then
                            fishAny = true
                            if need.perfect then
                                perfect = true
                            end
                            for _, pool in ipairs(resolvePools(need.item, need.text)) do
                                poolSet[pool] = true
                            end
                        end
                    end
                end
            end
        end
    end
    local pools = {}
    for pool in pairs(poolSet) do
        pools[#pools + 1] = pool
    end
    table.sort(pools)
    local keys = {}
    for key in pairs(needs) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    local parts = {}
    local shape = {}
    for _, key in ipairs(keys) do
        local need = needs[key]
        local label = key .. " " .. tostring(need.item or "pesca")
        local flag = need.fish and " [pesca]" or ""
        local progress = need.counter and "" or (" " .. need.have .. "/" .. need.count)
        parts[#parts + 1] = label .. progress .. flag
        shape[#shape + 1] = label .. flag
    end
    local signature = table.concat(parts, " ; ")
    state.needs = needs
    state.needPools = pools
    state.needFish = fishAny
    state.needPerfect = perfect
    if signature ~= state.needsSignature then
        state.needsSignature = signature
        state.wake = true
    end
    if #shape == 0 then
        logChange("needs", "Nenhum item necessario nas quests")
    else
        logChange("needs", "Itens necessarios: " .. table.concat(shape, " ; ") .. " | pools: " .. table.concat(pools, ","))
    end
end

local function needsLoop()
    while state.active do
        local ok, err = pcall(refreshNeeds)
        if not ok then
            warnOnce("needs:erro", "Erro ao detectar itens: " .. tostring(err))
        end
        task.wait(1)
    end
end

local function stepQuest(id, def, texts, checks)
    local pending = false
    for i, obj in ipairs(def.objectives or {}) do
        if objectiveDone(def, texts, checks, i) then
            continue
        end

        if obj.type == "turnIn" then
            for j = 1, i - 1 do
                if not objectiveDone(def, texts, checks, j) then
                    local kind = def.objectives[j].type
                    if kind == "count" or kind == "give" then
                        return false, "missing"
                    end
                    return false, "stuck"
                end
            end
        end

        local text = obj.display or texts[i] or ""
        local lower = tostring(text):lower()

        for _, handler in ipairs(handlers) do
            local matched
            if handler.match then
                matched = handler.match(lower, obj, id)
            else
                matched = lower:find(handler.pattern, 1, true) ~= nil
            end
            if matched then
                local ok, result = pcall(handler.run, id, obj, i)
                if result ~= "skip" then
                    if not ok then
                        warnOnce("handler:" .. id .. "#" .. i, "Erro no handler " .. tostring(handler.pattern or "match") .. ": " .. tostring(result))
                        return false, "stuck"
                    end
                    if result ~= false then
                        log("Handler " .. tostring(handler.pattern or "match") .. " -> " .. tostring(result))
                        return true
                    end
                    return false, "wait"
                end
                break
            end
        end

        if obj.type == "count" then
            local kind = fishKind(obj, lower)
            if kind then
                noteFishing(nil, text)
                if kind == "perfect" then
                    state.fishPerfect = true
                end
                warnOnce("fishobj:" .. id .. "#" .. i, "Objetivo de pesca em " .. id .. "#" .. i .. " [" .. kind .. "]: " .. clean(text))
                return false, "fish"
            end
        end

        if obj.type == "give" then
            local key = id .. "#" .. i
            local need = tonumber(obj.count) or 1
            local hudHave = tostring(texts[i] or obj.display or ""):match("%((%d+)/%d+%)")
            local have = tonumber(hudHave) or (obj.itemId and countItem(obj.itemId) or 0)
            local ready = counterDone(texts[i] or obj.display or "")
            if ready == nil then
                ready = obj.itemId ~= nil and have >= need
            end
            if not ready then
                state.giveReady[key] = nil
                local catchable = (obj.itemId and #poolsFor(obj.itemId) > 0) or lower:find("catch", 1, true) ~= nil
                if catchable then
                    noteFishing(obj.itemId, text)
                    warnOnce("give:" .. key, "Aguardando " .. (obj.itemId and (tostring(obj.itemId) .. " (" .. have .. "/" .. need .. ")") or clean(text)) .. ", precisa pescar")
                    return false, "fish"
                end
                if obj.itemId then
                    local entry = loadItems()[norm(obj.itemId)]
                    local words = entry and itemSearchWords(entry) or {tostring(obj.itemId):lower()}
                    local target = findWorldItem(words)
                    if target then
                        log("Item " .. tostring(obj.itemId) .. " no mapa, coletando " .. target:GetFullName())
                        collectObjects(target)
                        task.wait(1.5)
                        return true
                    end
                    warnOnce("give:" .. key .. ":missing", "Item " .. tostring(obj.itemId) .. " nao esta spawnando no mapa, seguindo para a proxima quest")
                    return false, "missing"
                end
            else
                if not state.giveReady[key] then
                    state.giveReady[key] = true
                    state.attempts[key] = 0
                    state.retryAt[key] = 0
                end
                if (state.retryAt[key] or 0) > os.clock() then
                    return false, "wait"
                end
                local used = state.attempts[key] or 0
                if used < 3 then
                    state.attempts[key] = used + 1
                    state.retryAt[key] = os.clock() + 10
                    local list = handInCandidates(id, text)
                    local choice = list[(used % math.max(#list, 1)) + 1]
                    if choice then
                        actOnNode(choice.npc, choice.node)
                    else
                        talkToNpc(npcFromText(text) or def.giver)
                    end
                    task.wait(2)
                    return true
                end
                warnOnce("limit:" .. key, "Tentativas esgotadas em " .. key .. " (" .. clean(text) .. ")")
                if def.staged then
                    return false, "stuck"
                end
                continue
            end
        end

        local candidates
        local exhausted = false
        if obj.type == "turnIn" then
            candidates = index.complete[id]
        elseif obj.type == "songKnown" and obj.songId then
            candidates = refCandidates(obj.songId, text)
        elseif obj.type == "dataFlag" then
            if type(obj.path) == "table" then
                candidates = index.setData[pathKey(obj.path)]
            end
            if not candidates or #candidates == 0 then
                candidates = refCandidates(id, text)
            end
        end

        if candidates and #candidates > 0 and obj.type ~= "turnIn" then
            local taken = state.usedNode[id]
            if taken then
                local free = {}
                for _, entry in ipairs(candidates) do
                    local owner = taken[entry.npc .. ":" .. entry.node]
                    if owner == nil or owner == i then
                        free[#free + 1] = entry
                    end
                end
                if #free == 0 then
                    exhausted = true
                end
                candidates = free
            end
        end

        if candidates and #candidates > 0 then
            local key = id .. "#" .. i
            local used = state.attempts[key] or 0
            local limit = obj.type == "turnIn" and (tonumber(env.QuestAutoAttempts) or 4) or math.min(3, #candidates + 1)
            if (state.retryAt[key] or 0) > os.clock() then
                return false, "wait"
            end
            if used < limit then
                local choice = candidates[(used % #candidates) + 1]
                if obj.type == "dataFlag" then
                    local ready, reason = prepareItem(key, text, choice.npc)
                    if not ready then
                        return false, reason or "missing"
                    end
                end
                if actOnNode(choice.npc, choice.node) then
                    state.usedNode[id] = state.usedNode[id] or {}
                    state.usedNode[id][choice.npc .. ":" .. choice.node] = i
                    state.attempts[key] = used + 1
                    state.misses[key] = 0
                else
                    state.retryAt[key] = os.clock() + 15
                    if registerMiss(key) then
                        return false, "missing"
                    end
                end
                task.wait(2)
                return true
            end
            warnOnce("limit:" .. key, "Tentativas esgotadas em " .. key .. " (" .. clean(text) .. ")")
            if obj.type == "turnIn" or (def.staged and obj.type ~= "dataFlag") then
                return false, "stuck"
            end
            exhausted = true
        end

        local npc = not exhausted and (obj.npc or (obj.type == "turnIn" and def.giver) or npcFromText(text)) or nil
        if npc then
            local key = id .. "#" .. i
            local limit = obj.type == "turnIn" and 3 or 1
            local used = state.attempts[key] or 0
            if (state.retryAt[key] or 0) > os.clock() then
                return false, "wait"
            end
            if used < limit then
                if talkToNpc(npc) then
                    state.attempts[key] = used + 1
                    state.misses[key] = 0
                else
                    state.retryAt[key] = os.clock() + 15
                    if registerMiss(key) then
                        return false, "missing"
                    end
                end
                task.wait(2)
                return true
            end
            warnOnce("limit:" .. key, "Tentativas esgotadas em " .. key .. " (" .. clean(text) .. ")")
            if obj.type == "turnIn" or def.staged then
                return false, "stuck"
            end
            continue
        end

        local objKey = "obj:" .. id .. "#" .. i
        local progressText = tostring(texts[i] or "")
        if state.objProgress[objKey] ~= progressText then
            state.objProgress[objKey] = progressText
            state.attempts[objKey] = 0
            state.retryAt[objKey] = 0
        end
        local target = objectFromText(text)
        local searchWorld = exhausted or not candidates or #candidates == 0
        if not target and searchWorld then
            local missed = state.attempts[objKey] or 0
            if missed < 3 and (state.retryAt[objKey] or 0) <= os.clock() then
                local words = worldWords(text)
                if #words > 0 then
                    local exclude = obj.type == "count" and state.collected[objKey] or nil
                    target = findWorldItem(words, exclude)
                    if not target and missed >= 1 then
                        target = searchItem(words)
                    end
                end
                if not target then
                    state.attempts[objKey] = missed + 1
                    state.retryAt[objKey] = os.clock() + 20
                    warnOnce("world:none:" .. objKey .. ":" .. missed, "Nada no mapa para " .. clean(text) .. " (tentativa " .. (missed + 1) .. ")")
                end
            end
        end
        if target then
            local key = objKey
            local used = state.attempts[key] or 0
            if (state.retryAt[key] or 0) > os.clock() then
                return false, "wait"
            end
            if used < 3 then
                state.attempts[key] = used + 1
                state.retryAt[key] = os.clock() + 15
                log("Objeto detectado " .. target:GetFullName() .. " para " .. key)
                collectObjects(target, obj.type == "dataFlag")
                if obj.type == "count" then
                    state.collected[key] = state.collected[key] or {}
                    state.collected[key][target] = true
                end
                task.wait(2)
                return true
            end
            warnOnce("limit:" .. key, "Tentativas esgotadas em " .. key .. " (" .. clean(text) .. ")")
        end

        warnOnce("manual:" .. id .. "#" .. i, "Objetivo manual em " .. id .. "#" .. i .. ": " .. clean(text) .. " [" .. tostring(obj.type) .. "]")
        if obj.type == "count" then
            if def.staged then
                return false, "missing"
            end
            pending = true
        else
            return false, "stuck"
        end
    end
    if pending then
        return false, "missing"
    end
    return false, "stuck"
end

-- // Index e areas
local indexMissing, markIndexNeed, nextIndexPool, locationIs, pickFishPool, goToPool

do
    local areaSuffix = {
        songkeepergrove = "sg",
        bluestonecavern = "bc",
        sorinrespite = "sr",
        talltrees = "tt",
        sanctummagus = "sm",
    }

    local indexTable
    local indexProbedAt = -100

    local function findIndexTable()
        if indexTable and os.clock() - indexProbedAt < 60 then
            return indexTable
        end
        indexProbedAt = os.clock()
        indexTable = nil
        local controller = okRegistry and Registry.C and Registry.C.Data
        if type(controller) ~= "table" then
            return nil
        end
        local visited = {}
        local function search(tbl, depth)
            if visited[tbl] or depth > 4 then
                return nil
            end
            visited[tbl] = true
            for key, value in pairs(tbl) do
                if type(value) == "table" then
                    local lowered = tostring(key):lower()
                    if lowered:find("index", 1, true) or lowered:find("codex", 1, true) or lowered:find("discover", 1, true) then
                        return value
                    end
                    local found = search(value, depth + 1)
                    if found then
                        return found
                    end
                end
            end
            return nil
        end
        local ok, found = pcall(search, controller, 0)
        indexTable = ok and found or nil
        return indexTable
    end

    local function containsItem(tbl, wanted, depth)
        if depth > 3 then
            return false
        end
        for key, value in pairs(tbl) do
            if norm(key) == wanted and value then
                return true
            end
            if type(value) == "string" and norm(value) == wanted then
                return true
            end
            if type(value) == "table" and containsItem(value, wanted, depth + 1) then
                return true
            end
        end
        return false
    end

    indexMissing = function(pool)
        loadPools()
        local items = poolItems[pool]
        local tbl = findIndexTable()
        if not items or #items == 0 or not tbl then
            return nil
        end
        local lookup = loadItems()
        local missing = {}
        local hits = 0
        for _, id in ipairs(items) do
            local entry = lookup[norm(id)]
            if not entry or rawget(entry.def, "itemType") == "scroom" then
                local ok, has = pcall(containsItem, tbl, norm(id), 0)
                if ok and has then
                    hits = hits + 1
                elseif not state.caughtIds[norm(id)] then
                    missing[#missing + 1] = id
                end
            end
        end
        if hits == 0 then
            return nil
        end
        return missing
    end

    local function collectIndexPools(cond, out)
        if type(cond) ~= "table" then
            return
        end
        if cond.type == "indexComplete" and cond.pool then
            out[tostring(cond.pool)] = true
        end
        for _, inner in ipairs(cond.conds or {}) do
            collectIndexPools(inner, out)
        end
    end

    markIndexNeed = function(id)
        local pools = {}
        local def = Quests and Quests[id]
        if type(def) == "table" then
            for _, cond in ipairs(def.available or {}) do
                collectIndexPools(cond, pools)
            end
        end
        for _, entry in ipairs(index.accept[id] or {}) do
            local module = npcModules[entry.npc]
            for _, item in ipairs(module and module.entry or {}) do
                collectIndexPools(item.cond, pools)
            end
        end
        for pool in pairs(pools) do
            if (state.indexCooldown[pool] or 0) <= os.clock() then
                local missing = indexMissing(pool)
                if missing == nil or #missing > 0 then
                    local need = state.indexNeed[pool]
                    if not need then
                        need = {quests = {}, start = state.fishCaught or 0, lastRetry = state.fishCaught or 0}
                        state.indexNeed[pool] = need
                        log("Index de " .. pool .. " pode estar incompleto, pescando la para liberar " .. id .. (missing and (" | faltando: " .. table.concat(missing, ",")) or ""))
                    end
                    need.quests[id] = true
                end
            end
        end
    end

    nextIndexPool = function(completed, active)
        local names = {}
        for pool in pairs(state.indexNeed) do
            names[#names + 1] = pool
        end
        table.sort(names)
        for _, pool in ipairs(names) do
            local need = state.indexNeed[pool]
            for id in pairs(need.quests) do
                if completed[id] or active[id] then
                    need.quests[id] = nil
                end
            end
            local missing = indexMissing(pool)
            local caught = (state.fishCaught or 0) - need.start
            local limit = missing == nil and 80 or 600
            if next(need.quests) == nil then
                state.indexNeed[pool] = nil
            elseif missing ~= nil and #missing == 0 then
                log("Index de " .. pool .. " completo, tentando aceitar de novo")
                state.indexNeed[pool] = nil
                for id in pairs(need.quests) do
                    state.skipAccept[id] = nil
                    state.refused[id] = nil
                end
            elseif caught >= limit then
                log("Limite de pesca no index de " .. pool .. ", tentando de novo em 1800s")
                state.indexNeed[pool] = nil
                state.indexCooldown[pool] = os.clock() + 1800
            else
                if missing == nil and caught - need.lastRetry >= 25 then
                    need.lastRetry = caught
                    for id in pairs(need.quests) do
                        state.skipAccept[id] = nil
                        state.refused[id] = nil
                    end
                end
                return pool
            end
        end
        return nil
    end

    locationIs = function(pool)
        local area = currentArea()
        return area ~= nil and norm(area) == norm(pool)
    end

    pickFishPool = function()
        local list = state.fishPools
        if #list == 0 then
            return nil
        end
        for _, pool in ipairs(list) do
            if locationIs(pool) then
                return pool
            end
        end
        for _, pool in ipairs(list) do
            if (state.poolCooldown[pool] or 0) <= os.clock() then
                return pool
            end
        end
        return nil
    end

    local function poolTargets(pool)
        local key = norm(pool)
        local list = {}
        local spot = state.poolSpots[key]
        if spot then
            list[#list + 1] = {name = "spot", position = spot}
        end
        local suffix = areaSuffix[key]
        local root = getRoot()
        local origin = root and root.Position
        local anchors = {}
        for npcId, position in pairs(state.npcPositions) do
            local inArea = state.npcArea[npcId] == key or (suffix ~= nil and npcId:match("_" .. suffix .. "$") ~= nil)
            if inArea and not state.badAnchor[pool .. ":" .. npcId] then
                anchors[#anchors + 1] = {name = npcId, position = position}
            end
        end
        table.sort(anchors, function(a, b)
            if origin then
                local distA = (a.position - origin).Magnitude
                local distB = (b.position - origin).Magnitude
                if distA ~= distB then
                    return distA < distB
                end
            end
            return a.name < b.name
        end)
        for _, anchor in ipairs(anchors) do
            list[#list + 1] = anchor
        end
        return list
    end

    goToPool = function(pool)
        if locationIs(pool) then
            return true
        end
        local targets = poolTargets(pool)
        if #targets == 0 then
            local waited = 0
            while state.active and scan.running and waited < 60 do
                task.wait(0.5)
                waited = waited + 0.5
            end
            if not scan.running then
                pcall(scanNpcs)
            end
            targets = poolTargets(pool)
        end
        if #targets == 0 then
            warnOnce("pool:notarget:" .. pool, "Sem destino conhecido para " .. pool .. ", pescando onde esta")
            state.poolCooldown[pool] = os.clock() + 120
            return false
        end
        local target = targets[1]
        log("Indo para " .. (areaKeys[norm(pool)] or pool) .. " via " .. target.name .. " | local atual: " .. tostring(currentArea()))
        streamAt(target.position)
        noclipOn()
        local arrived = flyTo(target.position + hoverOffset())
        noclipOff()
        local waited = 0
        while state.active and waited < 5 and not locationIs(pool) do
            task.wait(0.25)
            waited = waited + 0.25
        end
        if locationIs(pool) then
            log("Chegou em " .. pool)
            state.poolTries[pool] = 0
            return true
        end
        if arrived then
            if target.name == "spot" then
                state.poolSpots[norm(pool)] = nil
            else
                state.badAnchor[pool .. ":" .. target.name] = true
            end
        end
        log("Destino " .. target.name .. " nao caiu em " .. pool .. " | local: " .. tostring(currentArea()))
        state.poolTries[pool] = (state.poolTries[pool] or 0) + 1
        if state.poolTries[pool] >= 4 then
            state.poolTries[pool] = 0
            state.poolCooldown[pool] = os.clock() + 300
        end
        return false
    end
end

-- // Disponibilidade
local evalCond
local availability

local function questReadyNow(id)
    local def = Quests and Quests[id]
    if type(def) ~= "table" then
        return nil
    end
    local texts, checks = hudTexts(id)
    for i, obj in ipairs(def.objectives or {}) do
        if obj.type ~= "turnIn" and not objectiveDone(def, texts, checks, i) then
            return false
        end
    end
    return true
end

evalCond = function(cond, completed, active)
    if type(cond) ~= "table" then
        return nil
    end
    local kind = cond.type
    if kind == "level" then
        local required = tonumber(cond.value) or 0
        local level = playerLevel()
        if level then
            return level >= required
        end
        if (state.levelCapUntil or 0) > os.clock() and required >= (state.levelCap or math.huge) then
            return false
        end
        return nil
    elseif kind == "quest" then
        local done = completed[cond.quest] == true
        local running = active[cond.quest] == true
        if cond.state == "completed" then
            return done
        elseif cond.state == "none" then
            return not (done or running)
        elseif cond.state == "inProgress" then
            return running
        end
        return nil
    elseif kind == "questAvailable" then
        if completed[cond.quest] or active[cond.quest] then
            return false
        end
        local def = Quests and Quests[cond.quest]
        if type(def) ~= "table" then
            return nil
        end
        return availability(def, completed, active)
    elseif kind == "questReady" then
        if not active[cond.quest] then
            return false
        end
        return questReadyNow(cond.quest)
    elseif kind == "questStale" then
        if not active[cond.quest] then
            return false
        end
        return nil
    elseif kind == "indexComplete" then
        local missing = indexMissing(tostring(cond.pool))
        if missing == nil then
            return nil
        end
        return #missing == 0
    elseif kind == "hasItem" then
        return countItem(cond.itemId) >= (tonumber(cond.count) or 1)
    elseif kind == "data" then
        local path = cond.path
        if type(path) == "table" and path[1] == "Quests" and path[2] == "InProgress" and path[3] and cond.value == true then
            if not active[path[3]] then
                return false
            end
        end
        return nil
    elseif kind == "all" then
        local result = true
        for _, inner in ipairs(cond.conds or {}) do
            local value = evalCond(inner, completed, active)
            if value == false then
                return false
            end
            if value == nil then
                result = nil
            end
        end
        return result
    elseif kind == "any" then
        local result = false
        for _, inner in ipairs(cond.conds or {}) do
            local value = evalCond(inner, completed, active)
            if value == true then
                return true
            end
            if value == nil then
                result = nil
            end
        end
        return result
    end
    return nil
end

availability = function(def, completed, active)
    local result = true
    for _, cond in ipairs(def.available or {}) do
        local value = evalCond(cond, completed, active)
        if value == false then
            return false
        end
        if value == nil then
            result = nil
        end
    end
    return result
end

local function availableNow(def, completed, active)
    return availability(def, completed, active) ~= false
end

local function reachesAccept(module, startNode, questId)
    local seen = {}
    local queue = {startNode}
    while #queue > 0 do
        local name = table.remove(queue)
        if name and not seen[name] then
            seen[name] = true
            local node = module.nodes[name]
            if type(node) == "table" then
                for _, action in ipairs(node.serverActions or {}) do
                    if type(action) == "table" and action.type == "acceptQuest" and action.quest == questId then
                        return true
                    end
                end
                for _, choice in ipairs(node.choices or {}) do
                    if type(choice) == "table" and type(choice.next) == "string" then
                        queue[#queue + 1] = choice.next
                    end
                end
            end
        end
    end
    return false
end

local function offersQuest(npcId, questId, completed, active)
    local module = npcModules[npcId]
    if not module or type(module.entry) ~= "table" then
        return nil
    end
    for _, entry in ipairs(module.entry) do
        local value = true
        if entry.cond then
            value = evalCond(entry.cond, completed, active)
        end
        if value == nil then
            return nil
        end
        if value == true then
            return reachesAccept(module, entry.node, questId)
        end
    end
    return false
end

-- // Lote de quests
local function buildBatch(completed, active)
    local ids = {}
    local npcSet = {}
    for id, list in pairs(index.accept) do
        local def = Quests and Quests[id]
        local free = type(def) == "table" and not completed[id] and not active[id] and (state.skipAccept[id] or 0) <= os.clock()
        if free and (def.questType == "main" or env.QuestAutoSide ~= false) and availableNow(def, completed, active) then
            local reachable = false
            for _, entry in ipairs(list) do
                if (state.npcPositions[entry.npc] or findNpc(entry.npc)) and offersQuest(entry.npc, id, completed, active) ~= false then
                    reachable = true
                    npcSet[entry.npc] = true
                end
            end
            if reachable then
                ids[#ids + 1] = id
            end
        end
    end
    mainFirst(ids)
    return ids, countKeys(npcSet)
end

local function questAccepted(id)
    local waited = 0
    while state.active and waited < 4 do
        local _, set = activeQuestIds()
        if set[id] then
            return true
        end
        task.wait(0.5)
        waited = waited + 0.5
    end
    return false
end

local function progressSignature(completed)
    local count = 0
    for _ in pairs(completed) do
        count = count + 1
    end
    state.levelSeen = math.max(state.levelSeen or 0, tonumber(playerLevel()) or 0)
    return tostring(state.levelSeen) .. "|" .. count
end

local function tryAcceptNext(completed, active)
    local signature = progressSignature(completed)
    if state.signature ~= signature then
        state.signature = signature
        for id in pairs(state.skipAccept) do
            local def = Quests and Quests[id]
            if (state.refused[id] or 0) < 2 and type(def) == "table" and availability(def, completed, active) == true then
                state.skipAccept[id] = nil
            end
        end
    end
    if not state.batch then
        local batch, npcCount = buildBatch(completed, active)
        if #batch == 0 then
            state.idleUntil = os.clock() + 30
            logChange("idle", "Nenhum NPC com quest disponivel, nova verificacao em 30s")
            return false
        end
        state.logged["idle"] = nil
        state.batch = batch
        state.batchCursor = 1
        state.batchNumber = (state.batchNumber or 0) + 1
        log("Lote " .. state.batchNumber .. ": " .. #batch .. " quests em " .. npcCount .. " NPCs -> " .. table.concat(batch, ", "))
    end
    local batch = state.batch
    while state.batchCursor <= #batch do
        local id = batch[state.batchCursor]
        local key = "accept:" .. id
        if completed[id] or active[id] then
            state.attempts[key] = 0
            state.batchCursor = state.batchCursor + 1
        elseif Quests and Quests[id] and not availableNow(Quests[id], completed, active) then
            state.attempts[key] = 0
            log("Quest indisponivel, pulando: " .. id)
            state.batchCursor = state.batchCursor + 1
        elseif (state.attempts[key] or 0) >= 2 then
            local count = (state.refused[id] or 0) + 1
            state.refused[id] = count
            local delay = math.min(600 * 2 ^ (count - 1), 3600)
            state.skipAccept[id] = os.clock() + delay
            state.attempts[key] = 0
            log("Aceite recusado, adiado " .. delay .. "s: " .. id)
            markIndexNeed(id)
            local required = questLevel(Quests and Quests[id])
            if required and not playerLevel() then
                state.levelCap = math.min(state.levelCap or math.huge, required)
                state.levelCapUntil = os.clock() + 900
                log("Nivel provavelmente abaixo de " .. required .. ", pulando quests de nivel maior por 900s")
            end
            state.batchCursor = state.batchCursor + 1
        elseif (state.retryAt[key] or 0) > os.clock() then
            return false
        else
            local list = index.accept[id]
            local used = state.attempts[key] or 0
            local choice
            for offset = 0, #list - 1 do
                local candidate = list[((used + offset) % #list) + 1]
                if (state.npcPositions[candidate.npc] or findNpc(candidate.npc)) and offersQuest(candidate.npc, id, completed, active) ~= false then
                    choice = candidate
                    break
                end
            end
            if not choice then
                warnOnce("offer:" .. id, "Nenhum NPC oferece " .. id .. " agora, pulando")
                state.skipAccept[id] = os.clock() + 120
                state.attempts[key] = 0
                state.batchCursor = state.batchCursor + 1
            else
                state.attempts[key] = used + 1
                state.retryAt[key] = os.clock() + 6
                log("Aceitando " .. id .. " via " .. choice.npc .. ":" .. choice.node .. " (" .. state.batchCursor .. "/" .. #batch .. ")")
                local sent = actOnNode(choice.npc, choice.node)
                if sent and questAccepted(id) then
                    log("Quest aceita: " .. id)
                    state.attempts[key] = 0
                    state.refused[id] = nil
                    state.batchCursor = state.batchCursor + 1
                end
                task.wait(1)
                return true
            end
        end
    end
    log("Lote " .. state.batchNumber .. " concluido, verificando NPCs")
    state.batch = nil
    state.idleUntil = 0
    return false
end

-- // Loop principal
task.spawn(function()
    log("QuestAuto ligado")
    untuckQuests()
    task.spawn(scanNpcs)
    task.spawn(deathWatcher)
    task.spawn(needsLoop)
    while state.active do
        pcall(recordNpcs)
        state.cooling = false
        state.wake = false
        state.fishWanted = false
        state.fishPools = {}
        state.fishPerfect = false
        state.beat = os.clock()
        waitAlive()
        local strict = env.QuestAutoStrict ~= false
        local skip = type(env.QuestAutoSkip) == "table" and env.QuestAutoSkip or {}
        local ids, activeSet = activeQuestIds()
        local acted = false
        local blocked = false

        if #ids == 0 then
            warnOnce("vazio", "Nenhuma missao rastreada")
            if (state.retryAt["untuck"] or 0) <= os.clock() then
                state.retryAt["untuck"] = os.clock() + 30
                untuckQuests()
            end
        else
            state.warned["vazio"] = nil
        end

        for _, id in ipairs(ids) do
            if not state.active then
                break
            end
            if not skip[id] and (state.stuckUntil[id] or 0) <= os.clock() then
                local def = Quests and Quests[id]
                if type(def) == "table" then
                    local texts, checks = hudTexts(id)
                    local summary = describe(id, def, texts)
                    local bits = {}
                    for i = 1, #(def.objectives or {}) do
                        bits[#bits + 1] = objectiveDone(def, texts, checks, i) and "1" or "0"
                    end
                    local summarySignature = stripCounters(summary) .. "|" .. table.concat(bits)
                    if state.last[id] ~= summarySignature then
                        state.last[id] = summarySignature
                        log(summary)
                    end
                    local okStep, stepped, status = pcall(stepQuest, id, def, texts, checks)
                    if not okStep then
                        warnOnce("error:" .. id, "Erro em " .. id .. ": " .. tostring(stepped))
                        stepped = false
                        status = "stuck"
                    end
                    if stepped then
                        acted = true
                        state.focus = id
                        state.logged["missing:" .. id] = nil
                        break
                    end
                    if status == "stuck" then
                        state.stuckUntil[id] = os.clock() + 120
                        warnOnce("travada:" .. id, "Quest travada, seguindo para a proxima: " .. id)
                    elseif status == "missing" then
                        state.stuckUntil[id] = os.clock() + 60
                        logChange("missing:" .. id, "Sem progresso possivel agora, seguindo para a proxima quest: " .. id)
                    elseif status ~= "fish" and strict then
                        blocked = true
                        if state.focus ~= id then
                            state.focus = id
                            log("Foco na quest " .. id .. ", aguardando")
                        end
                        break
                    end
                else
                    warnOnce("def:" .. id, "Sem definicao para " .. id)
                end
            end
        end

        if state.needFish then
            state.fishWanted = true
            local present = {}
            for _, pool in ipairs(state.fishPools) do
                present[pool] = true
            end
            for _, pool in ipairs(state.needPools or {}) do
                if not present[pool] then
                    present[pool] = true
                    state.fishPools[#state.fishPools + 1] = pool
                end
            end
            if state.needPerfect then
                state.fishPerfect = true
            end
        end

        if not acted and not blocked and state.active and (state.idleUntil or 0) <= os.clock() then
            local ok, result = pcall(tryAcceptNext, completedSet(), activeSet)
            if not ok then
                warnOnce("accept:erro", "Erro no lote: " .. tostring(result))
                state.batch = nil
            end
            acted = ok and result or false
        end

        if not acted and (not state.fishWanted or #state.fishPools == 0) and next(state.indexNeed) then
            local indexPool = nextIndexPool(completedSet(), activeSet)
            if indexPool then
                state.fishWanted = true
                state.fishPools = {indexPool}
            end
        end

        waitAlive()
        local fishPool = state.fishWanted and pickFishPool() or nil
        if fishPool and not acted and state.active and not locationIs(fishPool) then
            goToPool(fishPool)
            acted = true
        end

        if acted then
            state.lastAct = os.clock()
        end
        if (state.fishRefused or 0) >= 3 and os.clock() - (state.fishRefusedAt or 0) > 60 then
            state.fishRefused = 0
        end
        local canFish = (state.fishRefused or 0) < 3
        fishSet(state.fishWanted and canFish and not acted and os.clock() - (state.lastAct or 0) > 4)

        local pause = acted and 1 or 3
        local slept = 0
        while state.active and slept < pause and not state.wake do
            task.wait(0.25)
            slept = slept + 0.25
        end
    end

    fishShutdown()
    noclipOff()
    for _, connection in ipairs(state.connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    env.QuestAutoHandler = nil
    log("QuestAuto desligado")
    if env.QuestAutoState == state then
        env.QuestAutoState = nil
    end
end)