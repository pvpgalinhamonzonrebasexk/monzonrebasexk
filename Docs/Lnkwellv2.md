# Inkwell

Módulo de console visual do Ecohub: mensagens coloridas, barra de progresso, spinner e grupos de texto.

## Índice

1. [Carregar](#1-carregar)
2. [Mensagens](#2-mensagens)
3. [Progress bar](#3-progress-bar)
4. [Spinner](#4-spinner)
5. [Group](#5-group)
6. [Limpeza](#6-limpeza)
7. [Exemplo completo](#7-exemplo-completo)
8. [Referência rápida](#8-referência-rápida)

---

## 1. Carregar

```lua
-- // Inkwell
local module = loadstring(game:HttpGet("https://raw.githubusercontent.com/pvpgalinhamonzonrebasexk/monzonrebasexk/refs/heads/main/Templates/Lnkwell.luau"))()

if not module then
    return
end
```

Todas as funções podem retornar `nil` se não conseguirem criar o elemento. Por isso, confira o retorno antes de usar o handle.

---

## 2. Mensagens

### Mensagem livre

```lua
local msg = module.print({
    message = "iniciando script dump",
    color = Color3.fromRGB(200, 200, 200),
})

if msg then
    msg.update({
        message = "dump em andamento...",
        color = Color3.fromRGB(120, 180, 255),
    })
end
```

| Opção | Tipo | Descrição |
|-------|------|-----------|
| `message` | string | Texto da linha |
| `color` | Color3 | Cor do texto |

| Handle | Descrição |
|--------|-----------|
| `msg.update(opts)` | Troca o texto e a cor |
| `msg.cleanup()` | Remove a linha |

### Mensagens prontas

```lua
local success = module.print_success("dump finalizado com sucesso")
local warning = module.print_warning("bytecode v5 pode ter erros")
local failure = module.print_error("falha ao decompile: script protegido")
local info = module.print_info("65 scripts encontrados no jogo")
```

| Função | Uso |
|--------|-----|
| `module.print_success(texto)` | Sucesso |
| `module.print_warning(texto)` | Aviso |
| `module.print_error(texto)` | Erro |
| `module.print_info(texto)` | Informação |

Cada uma retorna um handle com `cleanup()`.

---

## 3. Progress bar

```lua
local bar = module.progressbar({
    message = "decompilando scripts",
    style = "block",
    bar_size = 10,
    show_percent = true,
})

if bar then
    for index = 1, 65 do
        bar.set_message_and_progress(
            "decompilando scripts (" .. index .. "/65)",
            math.floor(index / 65 * 100)
        )

        task.wait()
    end

    bar.complete("decompilando scripts")
end
```

| Opção | Tipo | Descrição |
|-------|------|-----------|
| `message` | string | Texto ao lado da barra |
| `style` | string | Estilo visual da barra (ex.: `"block"`) |
| `bar_size` | number | Tamanho da barra em caracteres |
| `show_percent` | boolean | Mostra a porcentagem |

| Handle | Descrição |
|--------|-----------|
| `bar.set_message_and_progress(texto, porcentagem)` | Atualiza texto e progresso (0 a 100) |
| `bar.complete(texto)` | Finaliza a barra com o texto final |
| `bar.cleanup()` | Remove a barra |

---

## 4. Spinner

```lua
local spin = module.spinner({
    message = "buscando remotes no jogo",
    speed = 0.15,
})

if spin then
    task.wait(2)

    spin.set_message("analisando RemoteEvent e RemoteFunction")

    task.wait(2)

    spin.complete("remotes salvos com sucesso")
end
```

| Opção | Tipo | Descrição |
|-------|------|-----------|
| `message` | string | Texto ao lado do spinner |
| `speed` | number | Segundos entre cada quadro da animação |

| Handle | Descrição |
|--------|-----------|
| `spin.set_message(texto)` | Troca o texto enquanto gira |
| `spin.complete(texto)` | Para o spinner e mostra o texto final |
| `spin.cleanup()` | Remove o spinner |

---

## 5. Group

Bloco com título e várias linhas.

```lua
local grp = module.group("relatorio final")

if grp then
    grp.add("decompilados: 48")
    grp.add("via api: 12  |  via local: 36")
    grp.add("vazios: 17  |  total: 65")
    grp.add("api falhas: 0")
end
```

| Handle | Descrição |
|--------|-----------|
| `grp.add(texto)` | Adiciona uma linha ao grupo |
| `grp.cleanup()` | Remove o grupo |

---

## 6. Limpeza

Todo handle tem `cleanup()`. Chame quando não precisar mais do elemento.

```lua
if bar then
    bar.cleanup()
end

if spin then
    spin.cleanup()
end

if grp then
    grp.cleanup()
end
```

---

## 7. Exemplo completo

```lua
-- // Inkwell
local module = loadstring(game:HttpGet("https://raw.githubusercontent.com/pvpgalinhamonzonrebasexk/monzonrebasexk/refs/heads/main/Templates/Lnkwell.luau"))()

if not module then
    return
end

-- // Mensagens
local msg1 = module.print({
    message = "iniciando script dump",
    color = Color3.fromRGB(200, 200, 200),
})

local success = module.print_success("dump finalizado com sucesso")
local warning = module.print_warning("bytecode v5 pode ter erros")
local failure = module.print_error("falha ao decompile: script protegido")
local info = module.print_info("65 scripts encontrados no jogo")

if msg1 then
    msg1.update({
        message = "dump em andamento...",
        color = Color3.fromRGB(120, 180, 255),
    })
end

-- // Progress bar
local bar = module.progressbar({
    message = "decompilando scripts",
    style = "block",
    bar_size = 10,
    show_percent = true,
})

if bar then
    for index = 1, 65 do
        bar.set_message_and_progress(
            "decompilando scripts (" .. index .. "/65)",
            math.floor(index / 65 * 100)
        )

        task.wait()
    end

    bar.complete("decompilando scripts")
end

-- // Spinner
local spin = module.spinner({
    message = "buscando remotes no jogo",
    speed = 0.15,
})

if spin then
    task.wait(2)

    spin.set_message("analisando RemoteEvent e RemoteFunction")

    task.wait(2)

    spin.complete("remotes salvos com sucesso")
end

-- // Group
local grp = module.group("relatorio final")

if grp then
    grp.add("decompilados: 48")
    grp.add("via api: 12  |  via local: 36")
    grp.add("vazios: 17  |  total: 65")
    grp.add("api falhas: 0")
end

task.wait(5)

-- // Cleanup
local handles = { bar, spin, grp, msg1, success, warning, failure, info }

for _, handle in pairs(handles) do
    if handle then
        handle.cleanup()
    end
end
```

---

## 8. Referência rápida

| Função | Retorna | Métodos do handle |
|--------|---------|-------------------|
| `module.print(opts)` | handle | `update`, `cleanup` |
| `module.print_success(texto)` | handle | `cleanup` |
| `module.print_warning(texto)` | handle | `cleanup` |
| `module.print_error(texto)` | handle | `cleanup` |
| `module.print_info(texto)` | handle | `cleanup` |
| `module.progressbar(opts)` | handle | `set_message_and_progress`, `complete`, `cleanup` |
| `module.spinner(opts)` | handle | `set_message`, `complete`, `cleanup` |
| `module.group(titulo)` | handle | `add`, `cleanup` |