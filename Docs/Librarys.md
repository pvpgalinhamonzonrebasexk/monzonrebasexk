# Librarys

Documentação da library de UI do Ecohub: janela, tabs, sections e todos os elements.

## Índice

1. [Carregar a library](#1-carregar-a-library)
2. [Criar a janela](#2-criar-a-janela)
3. [Tabs e Sections](#3-tabs-e-sections)
4. [Elements](#4-elements)
   - [Toggle](#41-toggle)
   - [Button](#42-button)
   - [Slider](#43-slider)
   - [Dropdown](#44-dropdown)
   - [ColorPicker](#45-colorpicker)
   - [Paragraph](#46-paragraph)
5. [Exemplo completo: aba Status](#5-exemplo-completo-aba-status)
6. [Referência rápida](#6-referência-rápida)

---

## 1. Carregar a library

```lua
-- // Library
local Librarys = loadstring(game:HttpGet("https://raw.githubusercontent.com/pvpgalinhamonzonrebasexk/monzonrebasexk/refs/heads/main/Library/Librarys.luau"))()
```

> Só existe **uma janela** por vez. Executar o script de novo destrói a janela anterior, descarrega as features dela e remove qualquer GUI que tenha sobrado.

---

## 2. Criar a janela

```lua
-- // Window
local Window = Librarys:CreateWindow({
    Title = "Eco Hub",
    SubTitle = "by rip_sheldoohz",
    Size = UDim2.fromOffset(580, 350),
    MinimizeKey = Enum.KeyCode.RightShift,
})
```

| Opção | Tipo | Padrão | Descrição |
|-------|------|--------|-----------|
| `Title` | string | `"UILib"` | Título da janela |
| `SubTitle` | string | `""` | Subtítulo (também aceita `Subtitle`) |
| `Size` | UDim2 | `580 x 460` | Tamanho base, limitado ao tamanho da tela |
| `MinimizeKey` | Enum.KeyCode | `LeftControl` | Tecla que abre e fecha a janela |

No mobile a tecla é ignorada e aparece um botão flutuante arrastável.

### Métodos da janela

| Método | Descrição |
|--------|-----------|
| `Window:CreateTab(opts)` | Cria uma tab |
| `Window:GetTab(nomeOuIndice)` | Retorna uma tab |
| `Window:SelectTab(tab)` | Seleciona uma tab (objeto, nome ou índice) |
| `Window:SetTitle(texto)` | Troca o título |
| `Window:SetSubTitle(texto)` | Troca o subtítulo |
| `Window:SetMinimizeKey(tecla)` | Troca a tecla de minimizar |
| `Window:Toggle()` | Abre ou fecha |
| `Window:SetMinimized(estado)` | Define aberto ou fechado |
| `Window:IsMinimized()` | Retorna se está fechada |
| `Window:ClearSearch()` | Limpa a pesquisa |
| `Window:Destroy()` | Destrói a janela e descarrega as features |

---

## 3. Tabs e Sections

```lua
-- // Tab
local ElementsTab = Window:CreateTab({
    tab = "CheckBox",
    section = "Librarys",
    icon = "check-square",
})

-- // Section
local CheckBoxSection = ElementsTab:CreateSection("Checkbox")
```

| Opção da tab | Descrição |
|--------------|-----------|
| `tab` | Nome que aparece na barra lateral (também aceita `name`) |
| `section` | Título do grupo na barra lateral. Tabs com a mesma `section` ficam juntas |
| `icon` | Nome do ícone lucide, sem o prefixo `lucide-` |

| Método | Descrição |
|--------|-----------|
| `Tab:CreateSection(titulo)` | Cria um bloco dentro da página da tab |
| `Tab:Select()` | Seleciona a tab |
| `Section:SetTitle(texto)` | Troca o título da section |

---

## 4. Elements

Todos os elements aceitam `callback` (ou `Callback`). Erros dentro do callback são capturados e aparecem como notificação, sem derrubar o script.

Se o element tiver `title`, `name`, `text` ou `label`, ele entra automaticamente na pesquisa da janela.

### 4.1 Toggle

```lua
-- // Tab
local ElementsTab = Window:CreateTab({
    tab = "CheckBox",
    section = "Librarys",
    icon = "check-square",
})

local BoxSection = ElementsTab:CreateSection("Checkbox")

-- // Simples
local toggle1 = BoxSection:CreateToggle({
    title = "Wallbang",
    default = false,
    callback = function(state)
        print("Wallbang:", state)
    end,
})

-- // Com descrição
local toggle2 = BoxSection:CreateToggle({
    title = "God Mode",
    description = "Ativa invencibilidade",
    default = false,
    callback = function(state)
        print("God Mode:", state)
    end,
})

-- // Com keybind de teclado
local toggle3 = BoxSection:CreateToggle({
    title = "Speed Hack",
    description = "Aumenta velocidade",
    default = false,
    keybind = Enum.KeyCode.G,
    callback = function(state)
        print("Speed:", state)
    end,
})

-- // Com keybindCallback
local toggle4 = BoxSection:CreateToggle({
    title = "Fly",
    description = "Ativa voo",
    default = false,
    keybind = Enum.KeyCode.F,
    keybindCallback = function(state)
        print("Pressionou F, estado:", state)
    end,
    callback = function(state)
        print("Fly:", state)
    end,
})

-- // Com keybind de mouse
local toggle5 = BoxSection:CreateToggle({
    title = "Aimbot",
    default = false,
    keybind = Enum.UserInputType.MouseButton1,
    callback = function(state)
        print("Aimbot:", state)
    end,
})

local toggle6 = BoxSection:CreateToggle({
    title = "ESP",
    default = false,
    keybind = Enum.UserInputType.MouseButton2,
    callback = function(state)
        print("ESP:", state)
    end,
})

-- // Ativado por padrão
local toggle7 = BoxSection:CreateToggle({
    title = "Auto Farm",
    default = true,
    callback = function(state)
        print("Auto Farm:", state)
    end,
})

-- // Desabilitado
local toggle8 = BoxSection:CreateToggle({
    title = "Bloqueado",
    default = false,
    disabled = true,
    callback = function(state)
    end,
})
```

| Opção | Tipo | Descrição |
|-------|------|-----------|
| `title` | string | Texto principal |
| `description` | string | Texto menor abaixo do título |
| `default` | boolean | Estado inicial |
| `disabled` | boolean | Bloqueia a interação |
| `keybind` | KeyCode ou UserInputType | Atalho que alterna o toggle |
| `keybindCallback` | function(state) | Chamado só quando o atalho é usado |
| `callback` | function(state) | Chamado sempre que o estado muda |

```lua
-- // API Toggle
toggle1:Set(true)
toggle1:Set(false)
toggle1:Toggle()
toggle1:SetTitle("Wallbang ATIVO")
toggle2:SetDescription("Agora com dano 2x")
toggle8:SetDisabled(false)
toggle8:SetDisabled(true)
toggle3:SetKeybind(Enum.KeyCode.H)
toggle3:SetKeybind(Enum.UserInputType.MouseButton2)
toggle3:ClearKeybind()

local estado = toggle1:Get()
local bind = toggle3:GetKeybind()

toggle1:Destroy()
```

---

### 4.2 Button

```lua
-- // Tab
local ButtonTab = Window:CreateTab({
    tab = "Button",
    section = "Librarys",
    icon = "mouse-pointer",
})

local ButtonSection = ButtonTab:CreateSection("Button")

-- // Simples
local btn1 = ButtonSection:CreateButton({
    title = "Teleportar",
    callback = function()
        print("clicou")
    end,
})

-- // Com descrição
local btn2 = ButtonSection:CreateButton({
    title = "Resetar Personagem",
    description = "Respawna no spawn inicial",
    callback = function()
        print("resetou")
    end,
})

-- // Desabilitado
local btn3 = ButtonSection:CreateButton({
    title = "Bloqueado",
    disabled = true,
    callback = function()
    end,
})
```

| Opção | Tipo | Descrição |
|-------|------|-----------|
| `title` | string | Texto principal |
| `description` | string | Texto menor |
| `disabled` | boolean | Bloqueia o clique |
| `callback` | function() | Chamado ao clicar |

```lua
-- // API Button
btn1:SetTitle("Novo Titulo")
btn2:SetDescription("Nova descricao")
btn3:SetDisabled(false)
btn1:Fire()
```

---

### 4.3 Slider

```lua
-- // Tab
local SliderTab = Window:CreateTab({
    tab = "Slider",
    section = "Librarys",
    icon = "sliders",
})

local SliderSection = SliderTab:CreateSection("Slider")

-- // Simples
local sliderBasico = SliderSection:CreateSlider({
    title = "Velocidade",
    min = 0,
    max = 100,
    default = 16,
    callback = function(value)
        print("Velocidade:", value)
    end,
})

-- // Com descrição
local sliderDesc = SliderSection:CreateSlider({
    title = "Dano",
    description = "Multiplicador de dano do jogador",
    min = 1,
    max = 10,
    default = 1,
    callback = function(value)
        print("Dano:", value)
    end,
})

-- // Com sufixo
local sliderSufixo = SliderSection:CreateSlider({
    title = "Volume",
    min = 0,
    max = 100,
    default = 50,
    suffix = "%",
    callback = function(value)
        print("Volume:", value)
    end,
})

-- // Com decimais
local sliderDecimal = SliderSection:CreateSlider({
    title = "Gravidade",
    min = 0,
    max = 1,
    default = 0.5,
    rounding = 2,
    suffix = "x",
    callback = function(value)
        print("Gravidade:", value)
    end,
})

-- // Desabilitado
local sliderDisabled = SliderSection:CreateSlider({
    title = "Bloqueado",
    min = 0,
    max = 100,
    default = 30,
    disabled = true,
    callback = function(value)
    end,
})

-- // Completo
local sliderCompleto = SliderSection:CreateSlider({
    title = "Walk Speed",
    description = "Velocidade de caminhada",
    min = 0,
    max = 500,
    default = 16,
    rounding = 0,
    suffix = " sp",
    disabled = false,
    callback = function(value)
        local character = game.Players.LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = value
        end
    end,
})
```

| Opção | Tipo | Descrição |
|-------|------|-----------|
| `title` | string | Texto principal |
| `description` | string | Texto menor |
| `min` | number | Valor mínimo |
| `max` | number | Valor máximo |
| `default` | number | Valor inicial |
| `rounding` | number | Casas decimais |
| `suffix` | string | Texto depois do valor (`%`, `x`, ` sp`) |
| `disabled` | boolean | Bloqueia a interação |
| `callback` | function(value) | Chamado quando o valor muda |

```lua
-- // API Slider
sliderCompleto:Set(100)
sliderCompleto:SetMin(10)
sliderCompleto:SetMax(300)
sliderCompleto:SetSuffix(" km/h")
sliderCompleto:SetTitle("Speed")
sliderCompleto:SetDescription("Velocidade atualizada")
sliderCompleto:SetDisabled(true)
sliderCompleto:SetDisabled(false)

local atual = sliderCompleto:Get()
```

---

### 4.4 Dropdown

```lua
-- // Tab
local DropTab = Window:CreateTab({
    tab = "Dropdown",
    section = "Librarys",
    icon = "list",
})

local DropSection = DropTab:CreateSection("Dropdown")

-- // Simples
local dropBasico = DropSection:CreateDropdown({
    title = "Arma",
    values = { "Espada", "Arco", "Machado" },
    default = "Espada",
    callback = function(value)
        print("Arma:", value)
    end,
})

-- // Com descrição
local dropDesc = DropSection:CreateDropdown({
    title = "Classe",
    description = "Escolha a classe do personagem",
    values = { "Guerreiro", "Mago", "Arqueiro" },
    default = "Guerreiro",
    callback = function(value)
        print("Classe:", value)
    end,
})

-- // Multi seleção
local dropMulti = DropSection:CreateDropdown({
    title = "Efeitos Ativos",
    values = { "Velocidade", "Forca", "Invisibilidade", "Voo" },
    default = { "Velocidade", "Forca" },
    multi = true,
    callback = function(value)
        for efeito, ativo in pairs(value) do
            print(efeito, ativo)
        end
    end,
})

-- // Desabilitado
local dropDisabled = DropSection:CreateDropdown({
    title = "Bloqueado",
    values = { "A", "B", "C" },
    default = "A",
    disabled = true,
    callback = function(value)
    end,
})

-- // Completo
local dropCompleto = DropSection:CreateDropdown({
    title = "Time",
    description = "Escolha seu time",
    values = { "Azul", "Vermelho", "Verde" },
    default = "Azul",
    multi = false,
    disabled = false,
    callback = function(value)
        print("Time:", value)
    end,
})
```

| Opção | Tipo | Descrição |
|-------|------|-----------|
| `title` | string | Texto principal |
| `description` | string | Texto menor |
| `values` | table | Lista de opções |
| `default` | string ou table | Opção inicial (table quando `multi = true`) |
| `multi` | boolean | Permite escolher várias opções |
| `disabled` | boolean | Bloqueia a interação |
| `callback` | function(value) | Recebe a opção escolhida. Com `multi`, recebe uma tabela `{ [opção] = boolean }` |

---

### 4.5 ColorPicker

```lua
-- // Tab
local ColorTab = Window:CreateTab({
    tab = "ColorPicker",
    section = "Librarys",
    icon = "palette",
})

local ColorSection = ColorTab:CreateSection("ColorPicker")

-- // Simples
local cpBasico = ColorSection:CreateColorPicker({
    title = "Cor Principal",
    default = Color3.fromRGB(68, 120, 255),
    callback = function(color, transparency)
        print("Cor:", color)
    end,
})

-- // Com descrição
local cpDesc = ColorSection:CreateColorPicker({
    title = "Cor do Personagem",
    description = "Escolha a cor do seu personagem",
    default = Color3.fromRGB(255, 80, 80),
    callback = function(color, transparency)
        print("Cor Personagem:", color)
    end,
})

-- // Com transparência
local cpTransparency = ColorSection:CreateColorPicker({
    title = "Cor com Transparência",
    description = "Suporta transparência",
    default = Color3.fromRGB(80, 200, 120),
    transparency = 0.5,
    callback = function(color, transparency)
        print("Cor:", color, "Transparência:", transparency)
    end,
})

-- // Desabilitado
local cpDisabled = ColorSection:CreateColorPicker({
    title = "Bloqueado",
    default = Color3.fromRGB(150, 150, 150),
    disabled = true,
    callback = function(color, transparency)
    end,
})

-- // Completo
local cpCompleto = ColorSection:CreateColorPicker({
    title = "Cor do Time",
    description = "Escolha a cor do seu time",
    default = Color3.fromRGB(68, 120, 255),
    transparency = 0,
    disabled = false,
    callback = function(color, transparency)
        print("Time cor:", color, "alpha:", transparency)
    end,
})
```

| Opção | Tipo | Descrição |
|-------|------|-----------|
| `title` | string | Texto principal |
| `description` | string | Texto menor |
| `default` | Color3 | Cor inicial |
| `transparency` | number | Transparência inicial (0 a 1) |
| `disabled` | boolean | Bloqueia a interação |
| `callback` | function(color, transparency) | Chamado quando a cor muda |

---

### 4.6 Paragraph

Bloco de texto que pode ser atualizado em tempo real.

```lua
-- // Paragraph
local paraServidor = ParaSection:CreateParagraph({
    title = "Servidor",
    description = "Carregando...",
})

local paraPlayer = ParaSection:CreateParagraph({
    title = player.DisplayName .. " (@" .. player.Name .. ")",
    description = "Carregando...",
    thumbnail = player.UserId,
})

paraServidor:SetDescription("Novo texto")
```

| Opção | Tipo | Descrição |
|-------|------|-----------|
| `title` | string | Título |
| `description` | string | Texto (aceita `\n` para quebrar linha) |
| `thumbnail` | number | UserId para mostrar o avatar |

---

## 5. Exemplo completo: aba Status

Atualiza servidor e jogador a cada 1 segundo.

```lua
-- // Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local player = Players.LocalPlayer

-- // Tab
local ParaTab = Window:CreateTab({
    tab = "Status",
    section = "Librarys",
    icon = "activity",
})

local ParaSection = ParaTab:CreateSection("Paragraph")

-- // Paragraphs
local paraServidor = ParaSection:CreateParagraph({
    title = "Servidor • by rip_sheldoohz",
    description = "Carregando...",
})

local paraPlayer = ParaSection:CreateParagraph({
    title = player.DisplayName .. " (@" .. player.Name .. ")",
    description = "Carregando...",
    thumbnail = player.UserId,
})

-- // Servidor
local updateServer = function(dt)
    local total = #Players:GetPlayers()
    local max = Players.MaxPlayers
    local jobId = "Privado"

    if game.JobId ~= "" then
        jobId = game.JobId:sub(1, 20) .. "..."
    end

    local pingOk, ping = pcall(function()
        return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
    end)

    local pingText = "N/A"

    if pingOk then
        pingText = tostring(ping) .. " ms"
    end

    local fps = math.floor(1 / dt)

    paraServidor:SetDescription(
        "Jogadores: " .. total .. " / " .. max .. "\n" ..
        "Job ID: " .. jobId .. "\n" ..
        "Ping: " .. pingText .. "\n" ..
        "FPS: " .. fps
    )
end

-- // Jogador
local updatePlayer = function()
    local character = player.Character

    if not character then
        paraPlayer:SetDescription("Sem personagem")
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    local leaderstats = player:FindFirstChild("leaderstats")
    local level = leaderstats and leaderstats:FindFirstChild("Level")

    local health = "N/A"
    local walkSpeed = "N/A"
    local jumpPower = "N/A"
    local levelText = "N/A"
    local position = "N/A"

    if humanoid then
        health = math.floor(humanoid.Health) .. " / " .. math.floor(humanoid.MaxHealth)
        walkSpeed = tostring(humanoid.WalkSpeed)
        jumpPower = tostring(humanoid.JumpPower)
    end

    if level then
        levelText = tostring(level.Value)
    end

    if root then
        local point = root.Position
        position = "X: " .. math.floor(point.X) .. " Y: " .. math.floor(point.Y) .. " Z: " .. math.floor(point.Z)
    end

    paraPlayer:SetDescription(
        "Vida: " .. health .. "\n" ..
        "WalkSpeed: " .. walkSpeed .. "\n" ..
        "JumpPower: " .. jumpPower .. "\n" ..
        "Nível: " .. levelText .. "\n" ..
        "Posição: " .. position
    )
end

-- // Loop
local elapsed = 0

local connection = RunService.Heartbeat:Connect(function(dt)
    elapsed = elapsed + dt

    if elapsed < 1 then
        return
    end

    elapsed = 0

    pcall(updateServer, dt)
    pcall(updatePlayer)
end)

-- // Unload
getgenv().StatusUnload = function()
    connection:Disconnect()
end
```

> O `StatusUnload` é chamado automaticamente quando a feature é descarregada (veja a Features API). Isso desconecta o loop e evita lag depois de fechar o hub.

---

## 6. Referência rápida

```lua
-- // Window
local Window = Librarys:CreateWindow({
    Title = "Hub",
    SubTitle = "by x",
    Size = UDim2.fromOffset(580, 350),
    MinimizeKey = Enum.KeyCode.RightShift,
})

-- // Tab e Section
local Tab = Window:CreateTab({
    tab = "Nome",
    section = "Grupo",
    icon = "icone",
})

local Section = Tab:CreateSection("Titulo")
```

```lua
-- // Elements
Section:CreateToggle({
    title = "X",
    default = false,
    callback = function(state)
    end,
})

Section:CreateButton({
    title = "X",
    callback = function()
    end,
})

Section:CreateSlider({
    title = "X",
    min = 0,
    max = 100,
    default = 50,
    callback = function(value)
    end,
})

Section:CreateDropdown({
    title = "X",
    values = { "A", "B" },
    default = "A",
    callback = function(value)
    end,
})

Section:CreateColorPicker({
    title = "X",
    default = Color3.new(1, 1, 1),
    callback = function(color, alpha)
    end,
})

Section:CreateParagraph({
    title = "X",
    description = "Texto",
})

Section:CreateElement("NomeRegistrado", {
    text = "X",
})
```