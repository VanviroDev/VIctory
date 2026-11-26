# GTA6 no PC — o que foi otimizado para esta máquina

Tudo mora em **`C:\GTA6-PC`**. Esta pasta é portátil: pode mover ou copiar
inteira, o `GTA6.exe` reextrai o runtime de dentro dele se faltar arquivo.

## A máquina

| peça | modelo |
|---|---|
| CPU | Ryzen 5 5600G — Zen 3, 6 núcleos / 12 threads, AVX2, sem AVX-512 |
| RAM | 16 GB |
| GPU | RTX 3060 Ti 8 GB |
| Sistema | Windows 10 19045 x64 |

## O que está na pasta

| arquivo | o que é |
|---|---|
| `GTA6.exe` | launcher único: runtime, Agility SDK, controles e estes docs embutidos |
| `victory.exe` | runtime VIctory (DexNom RayTime) compilado para esta máquina |
| `victory-play.exe` | launcher de linha de comando usado pelo `GTA6.exe` |
| `victory-warm.exe` | aquece o cache de shaders |
| `D3D12\D3D12Core.dll` | Agility SDK 1.620.2 (Shader Model 6.6) |
| `game-path.txt` | caminho do `game_scarlett_master.exe` (UTF-8 sem BOM) |
| `cache\` | shaders traduzidos e texturas convertidas |
| `state\` | saves, telemetria e relatórios de crash |
| `logs\` | log de cada execução; `latest.txt` aponta para a última |
| `CONTROLES.md` | mapa de teclas e mouse |
| `OTIMIZACOES.md` | este documento |

## Build (o que faz o binário ser desta máquina)

`Cargo.toml` e `.cargo/config.toml` do fork DexNom RayTime:

- `-C target-cpu=znver3` — o compilador usa Zen 3 (AVX2, FMA, etc.) em vez do
  x86-64 genérico.
- `lto = "fat"` + `codegen-units = 1` + `opt-level = 3` — código inteiro
  otimizado junto; menos chamadas e menos cópia no caminho de submissão.
- `debug = "line-tables-only"` — o crash ainda aponta arquivo e linha sem
  inflar o binário.
- Feature `diagnostics` — HUD de FPS, captura de frame, dump de alvos e logs
  de depuração. É a base de trabalho; o perfil final pode sair sem ela.

## Runtime (o que o jogo recebe)

Perfil **1080p** (`JOGAR 1080p`):

```
--no-rt --console series-s --local-gpu-memory --sparse-textures --no-upload-ahead
VICTORY_DISPLAY_MODE=1920x1080
VICTORY_FILL_WORKERS=6
VICTORY_WIDE_WORKERS=6
VICTORY_PARALLEL_PRELUDES=1
VICTORY_AMBIENT_FALLBACK=1
VICTORY_FSR_4K=0
VICTORY_LOG=warn
```

Perfil **1440p** (`JOGAR 1440p`):

```
--no-rt --console series-x --1080p-to-1440p --local-gpu-memory --sparse-textures --no-upload-ahead
VICTORY_DISPLAY_MODE=2560x1440
```

O que cada um faz:

- **`VICTORY_DISPLAY_MODE`** — o título achava que a TV era 4K e renderizava
  uma cena 3840x2160 para uma janela 1920x1080. Agora ele recebe o tamanho da
  janela e renderiza nela. É a maior economia de GPU/VRAM do conjunto.
- **`--console series-s`** — perfil de console mais leve (Lockhart), adequado
  aos 8 GB de VRAM.
- **`--console series-x --1080p-to-1440p`** — o jogo renderiza 1080p e entrega
  1440p; mais bonito, mais VRAM. Use só se o 1080p estiver estável.
- **`--sparse-textures`** — texturas esparsas: só os mips usados ficam na VRAM.
- **`--local-gpu-memory`** — recursos na memória local da GPU, não na RAM do
  sistema.
- **`--no-upload-ahead`** — não envia texturas adiantadas; segura a VRAM em
  8 GB.
- **`VICTORY_FILL_WORKERS=6`** — até 6 threads preparando cópias de buffers.
- **`VICTORY_WIDE_WORKERS=6`** — até 6 threads no destile/hash de texturas
  (o padrão do código é 3 em um 6c/12t).
- **`VICTORY_PARALLEL_PRELUDES=1`** — grava os prelúdios de submissão em
  paralelo.
- **`VICTORY_AMBIENT_FALLBACK=1`** — iluminação ambiente de reserva quando o
  passe do título não roda.
- **`VICTORY_FSR_4K=0`** — sem FSR; o perfil 1440p usa a escala do próprio
  jogo.

## Present (a imagem na janela)

O título apresenta mais de uma *plane* por frame (a cena e a interface/vídeo).
O runtime percorre as planes, escolhe a de maior área e, se ela for menor que
o último alvo de desenho do frame, apresenta o último alvo — o fallback que
tirou a tela preta. `VICTORY_PRESENT_LAST_TARGET=0` desliga o fallback.

O swap chain acompanha o tamanho da textura apresentada. Com o
`VICTORY_DISPLAY_MODE` no tamanho da janela, ele para de ir para 4K.

## Teclado e mouse

O teclado e o mouse somam no pad 0 mesmo com um controle Xbox conectado.
WASD no stick esquerdo, mouse no stick direito, LMB = RT, RMB = LT, Espaço /
Enter = A, Ctrl / Backspace = B, Esc = Start, Tab = View. A tabela completa
está em `CONTROLES.md`.

## FPS e o cap de 30

O título deste build de console chama o intervalo de frame com **33,333 ms**
(30 fps) no modo de qualidade, tanto em Series S quanto em Series X. Isso é
escolha do jogo, não falta de GPU: no logo, a GPU fica em 0% e a CPU em 5%.

Para testar 60 fps sem tocar no jogo:

```
set VICTORY_FRAME_INTERVAL=16667
```

O runtime passa a acordar o título a cada 16,667 ms. Se a simulação do jogo
for baseada em tempo real, ele roda a 60 fps com a mesma velocidade; se for
baseada no intervalo que ele mesmo pediu, pode acelerar. Teste no logo e na
intro antes de deixar fixo. O padrão continua 30 fps.

## Onde está o quê

- **Otimização de compilação** — `.cargo/config.toml` e `Cargo.toml` do repo
  `DexNom-RayTime`.
- **Otimização de runtime** — variáveis acima, no `GTA6.exe` e nos `.cmd`.
- **Otimização de imagem** — `crates/victory-gpu/src/queue.rs` (present) e
  `host.rs` (swap chain).
- **Otimização de input** — `crates/victory-hle/src/modules/gameinput.rs`.
- **Build reproduzível** — `BUILD-MAQUINA.md` no repo.

## Limites conhecidos

- 29 pipelines do título ainda caem em `E_NOTIMPL`; alguns efeitos podem
  faltar.
- O cap de 30 fps é do título; o override de 60 fps é experimental.
- Crash em um ponto da tela inicial ainda em investigação; o relatório fica
  em `state\7952987A\temp\*.crash.log` e em `state\7952987A\crashes.log`.
