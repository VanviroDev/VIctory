# DexNom RayTime — fork do VanviroDev

Runtime de compatibilidade Xbox Series para PC. Fork do [DexNom RayTime](https://github.com/DexNom/VIctory), que por sua vez é fork do [VIctory do Marvisak](https://github.com/Marvisak/VIctory).

**Estado:** o título abre, toca o áudio da intro, mostra o logo e chega ao carregamento do mundo. O primeiro frame do mundo é montado (2.628 draws, 120 mil texturas) e depois o dispositivo D3D12 é removido por falta de RAM. Não é jogável do começo ao fim ainda — é uma build de pesquisa, e é isso que você vai encontrar.

Se você quer testar e mandar o log, este documento tem o caminho inteiro.

---

## Comece aqui — três passos

```powershell
# 1. Ferramentas (uma vez)
winget install Rustlang.Rustup
winget install Microsoft.VisualStudio.2022.BuildTools

# 2. Build (na pasta do repo)
.\Setup.cmd

# 3. Jogar
& "$env:LOCALAPPDATA\DexNom Runtime\victory-play.exe"
```

Se algo falhar, rode **`.\VERIFICAR.cmd`** antes de abrir issue. Ele confere tudo e diz exatamente o que falta.

---

## O que você precisa

| item | versão / detalhe |
| --- | --- |
| Windows | 10 build 19045 ou mais novo, **x64** |
| Rust | 1.85 ou mais novo, toolchain `x86_64-pc-windows-msvc` ([rustup.rs](https://rustup.rs)) |
| Visual Studio Build Tools | workload **Desktop development with C++** + Windows 10/11 SDK |
| Placa de vídeo | D3D12 com **Shader Model 6.6** (Agility SDK 1.620+) |
| RAM | **16 GB é o mínimo**, e é o gargalo desta build. 32 GB é o recomendado |
| VRAM | 8 GB recomendado |
| DirectX 12 Agility SDK | já vem no repo via `D3D12Core.dll` — não precisa instalar |

A build do repositório usa `-C target-cpu=znver3`. **Se a sua CPU não for Zen 3 ou mais nova**, troque para `native` em `.cargo/config.toml`, senão o binário dá instrução ilegal:

```toml
[target.x86_64-pc-windows-msvc]
rustflags = ["-C", "target-cpu=native"]
```

---

## O jogo não vem no repositório

Este projeto **não distribui jogo, dump, chave ou conteúdo de título**. Você precisa da sua própria cópia extraída da instalação Xbox Series, com o `game_scarlett_master.exe` e a pasta de dados ao lado dele.

O setup pede esse arquivo por uma janela de seleção e grava o caminho em `game-path.txt` (UTF-8 sem BOM). Nada do jogo é copiado ou modificado.

---

## Passo 1 — ferramentas

**Rust**

```powershell
winget install Rustlang.Rustup
rustup default stable-x86_64-pc-windows-msvc
```

Feche e reabra o terminal depois. `cargo --version` tem que responder.

**Visual Studio Build Tools**

```powershell
winget install Microsoft.VisualStudio.2022.BuildTools
```

No instalador, marque **Desktop development with C++**. É o que traz o `link.exe` e o Windows SDK.

Confira:

```powershell
where.exe link.exe
where.exe cargo
```

**Agility SDK**

O runtime declara `D3D12SDKVersion = 620` e `D3D12SDKPath = ".\D3D12\"`, então o `D3D12Core.dll` precisa ficar em `D3D12\D3D12Core.dll` ao lado do `victory.exe`. O setup baixa a versão 1.620.2 do pacote `Microsoft.Direct3D.D3D12` no nuget.org (35 MB, uma vez) e copia para o lugar certo — você não precisa instalar nada à mão. Sem ele o runtime morre com `0xC0000005` na criação do device.

---

## Passo 2 — build

```powershell
.\Setup.cmd
```

O script:

1. confere Windows x64, Rust e cargo (e acha o Visual Studio Build Tools sozinho);
2. pergunta o `game_scarlett_master.exe` e valida que o runtime consegue lê-lo;
3. gera as tabelas de formato (`Initialize-FormatTables.ps1`);
4. baixa o Agility SDK 1.620.2, se ainda não estiver em `D3D12\`;
5. compila `victory.exe`, `victory-play.exe` e `victory-warm.exe`;
6. instala tudo em `%LOCALAPPDATA%\DexNom Runtime` — binários, `D3D12\`, `game-path.txt`, os `.cmd` de perfil e a documentação;
7. cria os atalhos no menu Iniciar.

Primeira build leva de **10 a 20 minutos** (LTO fat, `codegen-units = 1`). As seguintes são rápidas.

Build manual, se preferir:

```powershell
cargo build --locked --release -p victory --features diagnostics --bins `
    --target x86_64-pc-windows-msvc --target-dir target
```

Binários em `target\x86_64-pc-windows-msvc\release\`.

---

## Passo 3 — jogar

**Pela linha de comando**

```powershell
& "$env:LOCALAPPDATA\DexNom Runtime\victory-play.exe"
```

**Pelos atalhos**

O setup cria três no menu Iniciar:

| atalho | perfil |
| --- | --- |
| DexNom RayTime (1080p) | Series S, sem ray tracing, ajustes de CPU/GPU/RAM |
| DexNom RayTime (1440p) | Series X, cena em 1080p, saída 1440p |
| DexNom RayTime (diagnóstico) | 1080p com `VICTORY_LOG=info` e o log copiado para a Área de Trabalho |

**Pelos scripts do repositório**

Os mesmos perfis, em `.cmd`. Eles usam os binários da pasta onde estão ou, se não houver, a cópia instalada em `%LOCALAPPDATA%\DexNom Runtime`:

```powershell
.\JOGAR-1080P.cmd          # perfil leve, 8 GB de VRAM (recomendado)
.\JOGAR-1440P.cmd          # Series X, renderiza 1080p e entrega 1440p
.\JOGAR-DIAGNOSTICO.cmd    # perfil 1080p com log detalhado, copia o log para a Area de Trabalho
.\AQUECER-CACHE.cmd        # traduz todos os shaders antes (minutos, uma vez)
.\VERIFICAR.cmd            # confere maquina, ferramentas, jogo e runtime
```

O primeiro boot é lento: o runtime traduz shaders e converte texturas. O cache fica em `cache\` e as execuções seguintes são bem mais rápidas.

---

## Perfis prontos

| perfil | flags | quando usar |
| --- | --- | --- |
| **1080p** (recomendado) | `--no-rt --console series-s --local-gpu-memory --sparse-textures --no-upload-ahead` | 8 GB de VRAM, 16 GB de RAM |
| **1440p** | `--no-rt --console series-x --1080p-to-1440p --local-gpu-memory --sparse-textures --no-upload-ahead` | 12 GB+ de VRAM, 32 GB de RAM |
| **RT experimental** | `--rt --console series-x --local-gpu-memory --sparse-textures --no-upload-ahead` | placa com folga; lento |

Ambiente do perfil 1080p (já embutido no `JOGAR-1080P.cmd`):

```bat
set VICTORY_DISPLAY_MODE=1920x1080
set VICTORY_FILL_WORKERS=6
set VICTORY_WIDE_WORKERS=12
set VICTORY_PIPELINE_WORKERS=8
set VICTORY_PARALLEL_PRELUDES=1
set VICTORY_WIDE_REFRESH=1
set VICTORY_INDIRECT_WINDOW=1
set VICTORY_FRAME_INTERVAL=16667
set VICTORY_INPLACE=1
set VICTORY_INPLACE_MB=2048
set VICTORY_TEXTURE_BUDGET_MB=2600
set VICTORY_TEXTURE_ROOM_PERCENT=80
set VICTORY_AMBIENT_FALLBACK=1
set VICTORY_FSR_4K=0
set VICTORY_LOG=warn
```

Cada uma dessas está explicada em [OTIMIZACOES.md](OTIMIZACOES.md).

---

## Variáveis de ambiente

### Desempenho

| variável | padrão | efeito |
| --- | --- | --- |
| `VICTORY_FRAME_INTERVAL` | do título (33333 = 30 fps) | intervalo de frame em µs. `16667` = 60 fps |
| `VICTORY_INDIRECT_WINDOW` | `0` | `1` = agrupa draws indiretos em janelas. **Maior ganho de GPU** |
| `VICTORY_WIDE_WORKERS` | metade dos núcleos, 2–6 | threads de destile/hash, até 12 |
| `VICTORY_FILL_WORKERS` | `1` | threads de cópia de buffer, até 6 |
| `VICTORY_PIPELINE_WORKERS` | metade dos núcleos, 2–8 | threads de compilação de pipeline, até 12 |
| `VICTORY_PARALLEL_PRELUDES` | `0` | `1` = prelúdios de submissão em paralelo |
| `VICTORY_WIDE_REFRESH` | `0` | `1` = refreshes de cópia em paralelo |
| `VICTORY_WIDE_BACK` | `1` | `0` desliga snapshots paralelos |
| `VICTORY_INPLACE` | `0` | `1` = usa páginas do título no lugar, sem copiar (economiza GB de RAM) |
| `VICTORY_INPLACE_MB` | `4096` | teto de memória do título emplaceada de uma vez |

### Memória

| variável | padrão | efeito |
| --- | --- | --- |
| `VICTORY_TEXTURE_BUDGET_MB` | sem teto | teto das cópias de textura que o título preenche |
| `VICTORY_TEXTURE_ROOM_PERCENT` | `90` | folga de VRAM antes de admitir cópias novas |
| `VICTORY_GPU_MEMORY_MB` | split do console | VRAM dedicada que o adaptador emulado reporta ao título |
| `VICTORY_CARD_WINDOWS_MB` | `0` | bytes de janelas que vão para a memória da placa |

### Diagnóstico

| variável | efeito |
| --- | --- |
| `VICTORY_LOG` | `warn` normal, `info` mostra FPS, `debug` gera ~6 MB em 25 s |
| `VICTORY_ADAPTER` | força adaptador por índice ou nome (`VICTORY_ADAPTER=NVIDIA`) |
| `VICTORY_D3D12_DEBUG` | liga a debug layer (só em build `diagnostics`) |
| `VICTORY_D3D12_DRED` | device-removed data (breadcrumbs, page fault) |
| `VICTORY_CAPTURE` / `VICTORY_CAPTURE_FRAMES` | captura frames para PNG |
| `VICTORY_DUMP_TARGETS` | dump dos alvos de draw |
| `VICTORY_TRAIL` | `0` desliga a trilha de comandos do relatório de crash |

A lista completa das ~200 variáveis está no código: procure por `VICTORY_` em `crates/`.

---

## Problemas comuns

| sintoma | causa | correção |
| --- | --- | --- |
| `cargo` não encontrado | Rust não está no PATH | reabra o terminal; `rustup default stable-x86_64-pc-windows-msvc` |
| `link.exe` não encontrado | Build Tools sem C++ | instale o workload **Desktop development with C++** |
| `illegal instruction` / crash na largada | binário compilado para znver3 em CPU mais velha | troque para `target-cpu=native` em `.cargo/config.toml` e rebuild |
| `0x887A0004` na criação do device | sem Shader Model 6.6 | atualize o driver; confira `D3D12\D3D12Core.dll` |
| `0x887A0005` + `0x887A0001` no carregamento | RAM esgotada | **é o bug conhecido** — veja abaixo |
| tela preta com áudio | present escolheu a plane errada | `VICTORY_PRESENT_LAST_TARGET=1` (padrão) |
| travado em 30 fps | é o cap do próprio título | `VICTORY_FRAME_INTERVAL=16667` |
| GPU em 0% no menu | não há o que desenhar | `VICTORY_INDIRECT_WINDOW=1`; normal no logo |
| setup recusa a pasta | instalou dentro do checkout | escolha uma pasta fora do repositório |
| janela nasce fora da tela | posição inicial do título | o launcher restaura e foca sozinho |

### O crash do carregamento

Sai com `0x887A0005` e motivo `0x887A0001`. A causa medida é **RAM física**, não GPU e não shader:

```
memory: 13376 MB private (7170 MB of it in memory; the PC has 344 MB free ...)
host copies of title memory: 3805 alive 2326 MB
host textures: 17879 alive 3503 MB
shared buffers: 3852 alive 2537 MB
```

O emulador guarda ~9 GB de cópias e o título emulado pede 7,7 GB. Em 16 GB não cabe. Com `VICTORY_INPLACE=1` e `VICTORY_TEXTURE_BUDGET_MB=2600` o tempo até o crash dobrou (110 s → 250 s) e a GPU passou a ser usada de verdade (0,7% → 18–40%).

Se você tem 32 GB, tente `VICTORY_TEXTURE_BUDGET_MB=4500` e `VICTORY_INPLACE_MB=4096` — e conte no issue se chegou mais longe.

---

## Controles

Teclado e mouse viram um pad Xbox virtual. WASD no stick esquerdo, mouse no stick direito, LMB = RT, RMB = LT, Espaço/Enter = A, Ctrl/Backspace = B, Esc = Start, Tab = View. Tabela completa em [CONTROLES.md](CONTROLES.md).

---

## Como reportar

Abra issue com:

1. saída de `.\VERIFICAR.cmd`;
2. o log gerado por `.\JOGAR-DIAGNOSTICO.cmd` (ele copia para a Área de Trabalho);
3. `state\<id>\temp\*.crash.log`;
4. sua placa, RAM e versão do Windows.

Com `VICTORY_LOG=info` o log já traz FPS, draws, memória e uso de GPU por frame. É o que permite comparar.

---

## Documentos

| arquivo | conteúdo |
| --- | --- |
| [BUILD-MAQUINA.md](BUILD-MAQUINA.md) | o build desta máquina, com os ajustes de compilador |
| [OTIMIZACOES.md](OTIMIZACOES.md) | cada otimização e a medição que a justifica |
| [CONTROLES.md](CONTROLES.md) | mapa de teclas e mouse |
| [BENCHMARK.md](BENCHMARK.md) | como medir antes e depois |
| [README.upstream.md](README.upstream.md) | README original, com os testes históricos |

---

## Créditos

- **Marvisak e os contribuidores do VIctory** — o runtime de compatibilidade original. [VIctory](https://github.com/Marvisak/VIctory)
- **ZSlayerHQ e os contribuidores do victory-world**, incluindo **triippywhale** e **asdaasdsaddf** — o trabalho de renderização Radeon que serve de base para este fork. [victory-world-runtime](https://github.com/ZSlayerHQ/victory-world-runtime)
- **Os contribuidores do XCL** — a camada de compatibilidade Xbox Series independente que informou a tradução de shader e a sincronização de memória CPU/GPU. [XCL](https://github.com/xcl-dev/xcl)
- **AMD** — o upscaler FSR 4.1.2 usado no perfil Quality 4K. [AMD FSR SDK](https://gpuopen.com/amd-fsr-sdk/)

## Licença

Código sob **GPL-3.0-or-later**. As tabelas de formato BCPack são dados fornecidos separadamente, fora dessa licença; o script de setup confere uma cópia local antes de usar. [LICENSE](LICENSE) · [Política de assets](docs/asset-policy.md)
