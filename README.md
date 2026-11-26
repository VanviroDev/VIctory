# DexNom RayTime — build do VanviroDev (RTX 3060 Ti)

Fork do [DexNom RayTime](https://github.com/DexNom/VIctory) (que por sua vez é fork do VIctory do Marvisak), ajustado para **uma máquina específica**: Ryzen 5 5600G, 16 GB de RAM, RTX 3060 Ti 8 GB e Windows 10 19045. O objetivo desta build é rodar o dump Xbox Series do GTA6 no PC com áudio, imagem, teclado/mouse e o máximo de FPS que o título permitir.

**Onde estamos:** o jogo abre, mostra o logo, toca o áudio da intro e chega à tela de carregamento. O carregamento ainda cai (crash em investigação) e o título se limita a 30 fps por conta própria. O detalhe de cada otimização está em [OTIMIZACOES.md](OTIMIZACOES.md); o passo a passo de build está em [BUILD-MAQUINA.md](BUILD-MAQUINA.md).

## A configuração desta build

| Peça | Modelo |
| --- | --- |
| CPU | AMD Ryzen 5 5600G — Zen 3, 6 núcleos / 12 threads, AVX2, sem AVX-512 |
| GPU | NVIDIA GeForce RTX 3060 Ti — 8 GB GDDR6, driver atual |
| RAM | 16 GB DDR4 |
| Sistema | Windows 10 Pro x64, build 19045 |
| Direct3D 12 | Agility SDK 1.620.2 (Shader Model 6.6) |
| Alvo | dump Xbox Series `GTA6.Xbox.v1.0.2.1-CYBERLEEK` |

A build de referência do fork (RX 7900 XTX / Core Ultra 9 / 64 GB) continua descrita mais abaixo, mas **não é o alvo desta fork**. Aqui o perfil é ray tracing desligado, 1080p nativo e orçamento de VRAM de 8 GB.

## Onde fica tudo

Tudo mora em **`C:\GTA6-PC`**. A pasta é portátil: pode mover ou copiar inteira, o `GTA6.exe` reextrai o runtime de dentro dele se faltar arquivo.

| Arquivo | O que é |
| --- | --- |
| `GTA6.exe` | launcher único: runtime, Agility SDK, controles e docs embutidos (~19 MB) |
| `victory.exe` | runtime VIctory compilado para esta máquina |
| `victory-play.exe` | launcher de linha de comando usado pelo `GTA6.exe` |
| `victory-warm.exe` | aquece o cache de shaders |
| `D3D12\D3D12Core.dll` | Agility SDK 1.620.2 |
| `game-path.txt` | caminho do `game_scarlett_master.exe` (UTF-8 sem BOM) |
| `cache\` | shaders traduzidos e texturas convertidas |
| `state\` | saves, telemetria e relatórios de crash |
| `logs\` | log de cada execução; `latest.txt` aponta para o último |
| `CONTROLES.md` | mapa de teclas e mouse |
| `OTIMIZACOES.md` | o que foi otimizado e por quê |

## Como jogar

1. Abra **`C:\GTA6-PC\GTA6.exe`** e clique em **JOGAR 1080p** (perfil recomendado para esta máquina).
2. Ou dê duplo clique em **`JOGAR-1080P.cmd`**, que usa o mesmo perfil sem a janela do launcher.
3. Para 1440p, use **JOGAR 1440p** / `JOGAR-1440P.cmd` — o jogo renderiza 1080p e entrega 1440p, com mais uso de VRAM.

O launcher também tem **Aquecer cache** (traduz todos os shaders antes de jogar), **Controles**, **Logs** e **Jogo** (troca a pasta do dump). Depois de iniciar, ele restaura e foca a janela do título, então o jogo sai da tela de configuração sem precisar de controle.

Sem janela: `GTA6.exe --play`, `GTA6.exe --play-1440p` ou `GTA6.exe --install`.

## Perfis

| Perfil | Console | RT | Resolução | Flags |
| --- | --- | --- | --- | --- |
| 1080p | Series S | off | nativa do Series S | `--no-rt --console series-s --local-gpu-memory --sparse-textures --no-upload-ahead` |
| 1440p | Series X | off | cena 1080p → saída 1440p | `--no-rt --console series-x --1080p-to-1440p --local-gpu-memory --sparse-textures --no-upload-ahead` |

Variáveis comuns aos dois perfis:

```
VICTORY_DISPLAY_MODE=1920x1080   (ou 2560x1440 no perfil 1440p)
VICTORY_FILL_WORKERS=6
VICTORY_WIDE_WORKERS=6
VICTORY_PARALLEL_PRELUDES=1
VICTORY_TEXTURE_BUDGET_MB=5200
VICTORY_TEXTURE_ROOM_PERCENT=80
VICTORY_AMBIENT_FALLBACK=1
VICTORY_FSR_4K=0
VICTORY_LOG=warn
```

## O que esta build muda em relação ao fork

### Compilação

- `-C target-cpu=znver3` — o binário usa Zen 3 (AVX2, FMA) em vez do x86-64 genérico.
- `lto = "fat"`, `codegen-units = 1`, `opt-level = 3` — código inteiro otimizado junto; menos chamadas e menos cópia no caminho de submissão.
- `debug = "line-tables-only"` — o crash ainda aponta arquivo e linha sem inflar o binário.

### Runtime

- **`VICTORY_DISPLAY_MODE`** — o título acreditava que a TV era 4K e renderizava uma cena 3840×2160 para uma janela 1920×1080. Agora ele recebe o tamanho da janela e renderiza nela. É a maior economia de GPU/VRAM do conjunto.
- **`VICTORY_TEXTURE_BUDGET_MB=5200`** — teto para as cópias de textura que o título preenche. Sem ele o processo chegava a 7,2 GB de 7,2 GB de orçamento da placa, o Windows movia texturas para a memória compartilhada e o dispositivo era removido.
- **`VICTORY_TEXTURE_ROOM_PERCENT=80`** — a folga de VRAM reservada antes de admitir novas cópias.
- **`VICTORY_FILL_WORKERS=6`** e **`VICTORY_WIDE_WORKERS=6`** — 6 threads preparando cópias de buffer e 6 no destile/hash de texturas (o padrão do código é 3 num 6c/12t).
- **`VICTORY_PARALLEL_PRELUDES=1`** — grava os prelúdios de submissão em paralelo.
- **`VICTORY_FRAME_INTERVAL`** — override do intervalo de frame em microssegundos. `16667` = 60 fps; sem ela, o runtime obedece o título (30 fps). Experimental: se a simulação for baseada no intervalo pedido, o jogo acelera.
- **`VICTORY_PRESENT_LAST_TARGET`** — ligado por padrão. O present percorre as planes do PresentX, escolhe a de maior área e, se ela for menor que o último alvo de desenho do frame, apresenta o último alvo (a cena). Era isso que tirava a tela preta. `0` desliga.

### Present

O título apresenta duas *planes*; cada registro tem `0x48` bytes (token, contagem, lista de recursos, reservados). O runtime percorre todas, escolhe a de maior área e apresenta o alvo certo. O swap chain acompanha o tamanho da textura apresentada — com o `VICTORY_DISPLAY_MODE` no tamanho da janela, ele para de ir para 4K.

### Teclado e mouse

Teclado e mouse somam no pad 0 mesmo com um controle Xbox conectado. WASD no stick esquerdo, mouse no stick direito, LMB = RT, RMB = LT, Espaço/Enter = A, Ctrl/Backspace = B, Esc = Start, Tab = View. A tabela completa está em [CONTROLES.md](CONTROLES.md).

### Launcher

`tools/pack/GTA6.cs` compila com `tools/pack/build.ps1` para um único `GTA6.exe`: runtime, `D3D12Core.dll`, `CONTROLES.md`, `BUILD-MAQUINA.md` e `OTIMIZACOES.md` vão embutidos como recursos. Na primeira execução ele extrai o que falta na própria pasta, lê o `game-path.txt` e chama o `victory-play.exe`.

## Onde estamos agora

O que já funciona:

- Boot completo do runtime, com Agility SDK e Shader Model 6.6.
- Logo Rockstar e áudio da intro.
- Imagem na janela em 1920×1080 (present multi-plane).
- Teclado e mouse no pad virtual.
- ~30,0 fps estáveis no logo e no menu, com quedas para 19–23 fps quando o streaming de texturas chega a 6–11 ms/frame e 12–15 MB/frame.

O que ainda falta:

- **Crash no carregamento.** O jogo chega à tela de carregamento e cai. O relatório fica em `state\7952987A\temp\*.crash.log` e em `state\7952987A\crashes.log`; o crash mais recente conhecido é `victory.exe+0x6179d0` (leitura de `0x1`), chamado de dentro de `victory-image-*.dll`. A simbolização com o PDB atual ainda não fecha porque o relatório é de um build anterior — reproduzir com o build atual é o próximo passo.
- **29 pipelines em `E_NOTIMPL`.** Slots `0x1c8`/`0x218`; o layout da struct de args ainda não é conhecido. Alguns efeitos podem faltar.
- **Cap de 30 fps do título.** O jogo chama `set_interval(33333)` no modo de qualidade, tanto em Series S quanto em Series X. No logo a GPU fica em 0% e a CPU em 5% — não é gargalo. O override é `VICTORY_FRAME_INTERVAL=16667`.
- **VRAM.** O processo chegava ao teto de 7,2 GB da placa e o dispositivo era removido. O teto de 5,2 GB para texturas do título é a correção em teste.

## Reproduzir o build

```powershell
$env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
cd C:\Users\Administrator\Downloads\DexNom-RayTime
cargo build --locked --release -p victory --features diagnostics --bins
```

Binários em `target\release`: `victory.exe`, `victory-play.exe`, `victory-warm.exe`. Copie os três para `C:\GTA6-PC` e rode `tools\pack\build.ps1` para gerar o `GTA6.exe` único.

## Variáveis de ambiente úteis

| Variável | Efeito |
| --- | --- |
| `VICTORY_LOG` | `warn` no uso normal; `info` para FPS; `debug` para diagnóstico (gera ~6 MB em 25 s) |
| `VICTORY_DISPLAY_MODE` | tamanho que o título recebe (`1920x1080`, `2560x1440`) |
| `VICTORY_RENDER_1080P` | força a cena em 1080p |
| `VICTORY_FRAME_INTERVAL` | intervalo de frame em µs (`16667` = 60 fps) |
| `VICTORY_FILL_WORKERS` / `VICTORY_WIDE_WORKERS` | threads de cópia e de textura |
| `VICTORY_TEXTURE_BUDGET_MB` / `VICTORY_TEXTURE_ROOM_PERCENT` | teto e folga de VRAM |
| `VICTORY_PRESENT_LAST_TARGET` | `0` desliga o fallback de present |
| `VICTORY_CAPTURE` / `VICTORY_CAPTURE_FRAMES` | captura frames para PNG |
| `VICTORY_DUMP_TARGETS` | dump dos alvos de draw |
| `VICTORY_D3D12_DEBUG` / `VICTORY_D3D12_GBV` | debug layer e validação por GPU (build diagnostics) |
| `VICTORY_TRAIL` | `0` desliga a trilha de comandos do relatório de crash |

## FSR Quality 4K (perfil original do fork)

O fork nasceu com um perfil Series X com ray tracing e FSR 4.1.2 Quality em 1440p → 4K, testado numa RX 7900 XTX. Ele continua no repositório para quem tem uma Radeon com folga de VRAM:

```powershell
& "$env:LOCALAPPDATA\DexNom Runtime\victory-play.exe" --rt --console series-x --local-gpu-memory --fsr-quality --sparse-textures --no-upload-ahead --capture-readbacks --rt-write-stats
```

O provider FidelityFX vai em `fidelityfx\` na pasta do runtime ou em `VICTORY_FIDELITYFX_DIR`. Nesta máquina (RTX 3060 Ti, 8 GB) o perfil usado é `--no-rt --console series-s`, sem FSR.

## Things to Be Done (upstream)

- **Reduce buffer copy-back.** Track which pages the GPU actually writes and read back only the ranges CPU consumers need.
- **Reduce VRAM use and stabilize texture streaming.** Measure local VRAM and GPU-shared system memory separately; look for duplicate resident resources and repeated mip uploads.
- **Improve frame-time stability.** Measure cold pipeline compilation and warm gameplay separately; compare pipeline counts and the rendered scene.

For a before-and-after test, use the same scene, camera, and driver. Report median and 95th-percentile frame times, dedicated and shared GPU memory, upload and copy-back time and bytes, and dropped draws or pending pipelines. [Benchmark notes](BENCHMARK.md)

## Credits

- **Marvisak and the VIctory contributors** created the original Windows compatibility runtime. [VIctory](https://github.com/Marvisak/VIctory)
- **ZSlayerHQ and the victory-world contributors**, including **triippywhale** and **asdaasdsaddf**, supplied the Radeon rendering work used as the basis for this fork. [victory-world-runtime](https://github.com/ZSlayerHQ/victory-world-runtime)
- **The XCL contributors** published an independent Xbox Series compatibility layer that informed shader translation and CPU/GPU memory synchronization. [XCL](https://github.com/xcl-dev/xcl)
- **AMD** supplies the FSR 4.1.2 upscaler used by the Quality 4K profile. [AMD FSR SDK](https://gpuopen.com/amd-fsr-sdk/)

The upstream README preserves the original credits and historical test results. [Upstream README](README.upstream.md)

## Licensing

VIctory source is licensed under GPL-3.0-or-later. The upstream project identifies the required BCPack format tables as separately supplied data outside that license. This source archive omits that file. The setup script verifies a local or upstream copy before use. [License](LICENSE) · [Upstream asset policy and table notice](docs/asset-policy.md)
