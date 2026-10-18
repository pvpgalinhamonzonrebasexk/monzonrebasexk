local CombatTab = Windows:CreateTab({
    Name = "Combat",
    Description = "Combat features",
    Icon = "crosshair"
})
local CombatSection = CombatTab:CreateSection("Aimbot")

local AimTab = Windows:CreateTab({
    Name = "Aim",
    Description = "Aim features",
    Icon = "target"
})
local AimSection = AimTab:CreateSection("Config")

local VisualsTab = Windows:CreateTab({
    Name = "Visuals",
    Description = "Visual features",
    Icon = "eye"
})
local VisualsSection = VisualsTab:CreateSection("ESP")

local PlayerTab = Windows:CreateTab({
    Name = "Player",
    Description = "Player features",
    Icon = "user"
})
local PlayerSection = PlayerTab:CreateSection("Character")

local MovementTab = Windows:CreateTab({
    Name = "Movement",
    Description = "Movement features",
    Icon = "move"
})
local MovementSection = MovementTab:CreateSection("Movement")

local WeaponsTab = Windows:CreateTab({
    Name = "Weapons",
    Description = "Weapon features",
    Icon = "crosshair"
})
local WeaponsSection = WeaponsTab:CreateSection("Weapons")

local WorldTab = Windows:CreateTab({
    Name = "World",
    Description = "World features",
    Icon = "globe"
})
local WorldSection = WorldTab:CreateSection("World")

local TeleportTab = Windows:CreateTab({
    Name = "Teleport",
    Description = "Teleport features",
    Icon = "map-pin"
})
local TeleportSection = TeleportTab:CreateSection("Locations")

local MiscTab = Windows:CreateTab({
    Name = "Misc",
    Description = "Miscellaneous features",
    Icon = "layers"
})
local MiscSection = MiscTab:CreateSection("Misc")

local ExploitTab = Windows:CreateTab({
    Name = "Exploit",
    Description = "Extra features",
    Icon = "code"
})
local ExploitSection = ExploitTab:CreateSection("Tools")