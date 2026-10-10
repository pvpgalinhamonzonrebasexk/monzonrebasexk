# Notifications

```lua
local Notifications = loadstring(game:HttpGet("https://raw.githubusercontent.com/EcohubPassouAqui/rip_sheldoohz/refs/heads/main/library/Notifications.luau"))()
local Notify = Notifications.Notify
```

## Notify

```lua
Notify({
    Title = "Early | Wave 1",
    Description = "This description is super long and should cause an overlap in wrapping",
    Duration = 5,
})

Notify("Description only")
Notify("Description only", 3)
Notify("Title", "Description", 5, "Warning")
Notifications("Description only")
```

## Properties

```lua
Notify({
    Title = "Title",
    Description = "Description",
    Duration = 5,
    Type = "Info",
    Color = Color3.fromRGB(255, 0, 0),
    Name = "Hub",
    Thumbnail = "rbxassetid://123",
    RichText = true,
    Callback = function() end,
    ClickToClose = true,
    Id = "download",
    Sound = "rbxassetid://123",
    Volume = 0.5,
})
```

```lua
Notify({ Title = "Persistent", Duration = 0 })
Notify({ Title = "No name", Name = false })
Notify({ Title = "No thumbnail", Thumbnail = false })
Notify({ Title = "Rich", Description = "<b>bold</b> <i>italic</i>", RichText = true })
Notify({ Title = "Click", Callback = function() print("clicked") end, ClickToClose = false })
```

## Types

```lua
Notifications.Info("Title", "Description", 4)
Notifications.Success("Title", "Description", 4)
Notifications.Warning("Title", "Description", 4)
Notifications.Error("Title", "Description", 4)
```

```lua
Notify({ Title = "Info", Type = "Info" })
Notify({ Title = "Success", Type = "Success" })
Notify({ Title = "Warning", Type = "Warning" })
Notify({ Title = "Error", Type = "Error" })
Notify({ Title = "Alias", Type = "ok" })
Notify({ Title = "Alias", Type = "warn" })
Notify({ Title = "Alias", Type = "err" })
```

```lua
Notifications.Types.Custom = Color3.fromRGB(255, 120, 0)
Notify({ Title = "Custom", Type = "Custom" })
```

## Handle

```lua
local handle = Notify({ Title = "Downloading", Description = "0%", Duration = 0 })

handle.Update({ Description = "50%" })
handle.Update({ Title = "Done", Description = "100%", Duration = 2 })
handle.Close()
handle.IsClosed()
handle.Frame
```

## Id

```lua
Notify({ Id = "download", Title = "Downloading", Description = "10%", Duration = 5 })
Notify({ Id = "download", Title = "Downloading", Description = "60%", Duration = 5 })
Notify({ Id = "download", Title = "Done", Description = "100%", Duration = 2 })
```

## Setters

```lua
Notifications.SetName("Hub")
Notifications.SetName(false)
Notifications.SetThumbnail("rbxassetid://123")
Notifications.SetSide("Left")
Notifications.SetSide("Right")
Notifications.SetPosition("TopLeft")
Notifications.SetPosition("TopRight")
Notifications.SetPosition("BottomLeft")
Notifications.SetPosition("BottomRight")
Notifications.SetDuration(4)
Notifications.SetGroup(true)
Notifications.SetMaxVisible(4)
Notifications.SetSound("rbxassetid://123", 0.5)
Notifications.SetSound(false)
Notifications.SetClickToClose(false)
```

## Control

```lua
Notifications.Clear()
Notifications.Destroy()
```

## Config

```lua
Notifications.Config.Name = false
Notifications.Config.GuiName = "Notifications"
Notifications.Config.Thumbnail = "rbxassetid://0"
Notifications.Config.Side = "Left"
Notifications.Config.Vertical = "Bottom"
Notifications.Config.Width = 320
Notifications.Config.Margin = 20
Notifications.Config.Padding = 8
Notifications.Config.MaxVisible = 6
Notifications.Config.DefaultDuration = 5
Notifications.Config.ThumbnailSize = 44
Notifications.Config.ShowProgress = true
Notifications.Config.HoverPause = true
Notifications.Config.Group = false
Notifications.Config.ClickToClose = true
Notifications.Config.Sound = false
Notifications.Config.SoundVolume = 0.5
Notifications.Config.TitleSize = 14
Notifications.Config.DescriptionSize = 13
Notifications.Config.NameSize = 11
Notifications.Config.TitleFont = Enum.Font.GothamSemibold
Notifications.Config.DescriptionFont = Enum.Font.Gotham
Notifications.Config.NameFont = Enum.Font.GothamBold
Notifications.Config.Background = Color3.fromRGB(22, 22, 27)
Notifications.Config.Stroke = Color3.fromRGB(55, 55, 66)
Notifications.Config.Accent = Color3.fromRGB(130, 110, 255)
Notifications.Config.TitleColor = Color3.fromRGB(255, 255, 255)
Notifications.Config.DescriptionColor = Color3.fromRGB(185, 185, 195)
Notifications.Config.TweenIn = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
Notifications.Config.TweenOut = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
```

## Utils

```lua
Notifications.NormalizeImage("rbxassetid://123")
Notifications.ResolveType("warn")
Notifications.GetParents()
Notifications.Protect(gui)
```

## Example

```lua
local Notifications = loadstring(game:HttpGet("https://raw.githubusercontent.com/EcohubPassouAqui/rip_sheldoohz/refs/heads/main/library/Notifications.luau"))()
local Notify = Notifications.Notify

task.wait(1)

Notify({
    Title = "Early | Wave 1",
    Description = "This description is super long and should cause an overlap in wrapping",
    Duration = 5,
})

task.wait(1)

Notify({
    Title = "Early | Wave 1",
    Description = "This description is super long and should cause an overlap in wrapping",
    Duration = 10,
})

task.wait(1)

Notify({
    Title = "Early | Wave 1",
    Description = "This description is super long and should cause an overlap in wrapping",
    Duration = 1,
})

task.wait(1)

Notify({
    Description = "This description is super long and should cause an overlap in wrapping",
    Duration = 3,
})
```