# GTA6 no PC — o que foi otimizado, com a medição de cada passo

Este documento explica cada ajuste desta build e o número que o justifica.
Nada aqui é "achismo de fórum": cada linha foi medida na máquina de referência
(Ryzen 5 5600G, 16 GB, RTX 3060 Ti 8 GB, Windows 10 19045).

Se você só quer jogar, leia o [README.md](README.md). Se quer entender por que
o runtime está configurado assim, ou quer ajustar para o seu hardware, este é o
lugar.

## A máquina de referência

| peça | modelo |
|---|---|
| CPU | Ryzen 5 5600G — Zen 3, 6 núcleos / 12 threads, AVX2, sem AVX-512 |
| RAM | 16 GB DDR4 |
| GPU | RTX 3060 Ti 8 GB |
| Sistema | Windows 10 19045 x64 |

## Resultado medido

Antes e depois do conjunto de runtime desta build, no mesmo ponto do
carregamento:

| métrica | antes | depois |
|---|---|---|
| uso de GPU durante o load | **0,7 %** | **18–40 %** (picos de 55 %) |
| FPS no carregamento | 1,2 | 30 (limitado pelo próprio título) |
| draws por frame no mundo | 2.628 com 4.673 descartados | 2.628 com os pipelines criados |
| tempo até o crash de RAM | ~110 s | **~250 s** |
| commit privado no pior instante | 16.239 MB | **13.376 MB** |
| texturas do host | 5.670 MB | **3.503 MB** |
| cópias da memória do título | 3.250 MB | **2.326 MB** |
| shared buffers | 3.481 MB | **2.537 MB** |

O crash ainda acontece em 16 GB, mas o dobro de tempo depois e com a placa
sendo usada de verdade. Em 32 GB o conjunto deve passar do ponto onde esta
build para.

## Build (o que faz o binário ser desta máquina)

`Cargo.toml` e `.cargo/config.toml`:

- `-C target-cpu=znver3` — o compilador usa Zen 3 (AVX2, FMA) em vez do x86-64
  genérico. **Se o seu CPU não for Zen 3 ou mais novo, troque para `native`**,
  senão o binário morre com instrução ilegal.
- `lto = "fat"` + `codegen-units = 1` + `opt-level = 3` — o crate inteiro é
  otimizado junto; menos chamadas e menos cópia no caminho de submissão.
- `debug = "line-tables-only"` — o relatório de crash ainda aponta arquivo e
  linha sem inflar o binário.
- Feature `diagnostics` — HUD de FPS, captura de frame, dump de alvos e os
  contadores que aparecem nos logs abaixo.

## Runtime — perfil 1080p (recomendado)

```
--no-rt --console series-s --local-gpu-memory --sparse-textures --no-upload-ahead
```

```
VICTORY_DISPLAY_MODE=1920x1080
VICTORY_FRAME_INTERVAL=16667
VICTORY_FILL_WORKERS=6
VICTORY_WIDE_WORKERS=12
VICTORY_PIPELINE_WORKERS=8
VICTORY_PARALLEL_PRELUDES=1
VICTORY_WIDE_REFRESH=1
VICTORY_INDIRECT_WINDOW=1
VICTORY_INPLACE=1
VICTORY_INPLACE_MB=2048
VICTORY_TEXTURE_BUDGET_MB=2600
VICTORY_TEXTURE_ROOM_PERCENT=80
VICTORY_AMBIENT_FALLBACK=1
VICTORY_FSR_4K=0
VICTORY_LOG=warn
```

### Vídeo

- **`VICTORY_DISPLAY_MODE`** — o título achava que a TV era 4K e renderizava
  3840x2160 para uma janela 1920x1080. Agora ele recebe o tamanho da janela.
  É a maior economia de GPU/VRAM do conjunto.
- **`VICTORY_FRAME_INTERVAL=16667`** — o título pede 33,333 ms (30 fps) por
  conta própria. O runtime acorda ele a cada 16,667 ms. O log confirma:
  `frame interval asked=33.333ms interval=16.667ms`.
- **`VICTORY_FSR_4K=0`** — sem FSR. O upscaler do título pede
  `DeserializeComputePipelineStateX`, recebe `E_NOTIMPL` e cai sozinho para o
  caminho "NewBE". Desligar evita a tentativa e os 29 pipelines que falham.

### GPU

- **`VICTORY_INDIRECT_WINDOW=1`** — **o maior ganho medido.** O título emite
  os mesh draws indiretos um registro por chamada, com um passe de compute
  entre duas esperas por registro. Agrupando os registros em uma janela por
  passe, a GPU saiu de **0,7 % para 18–55 %** durante o carregamento.
- **`--console series-s`** — perfil de console mais leve (Lockhart), adequado
  aos 8 GB de VRAM.
- **`--console series-x --1080p-to-1440p`** — renderiza 1080p e entrega 1440p.
  Mais bonito, mais VRAM e mais RAM. Só depois que o 1080p estiver estável.
- **`--sparse-textures`** — só os mips usados ficam na VRAM.
- **`--local-gpu-memory`** — buffers de input em upload heap / pool L1, via
  `D3D12_OPTIONS16.GPUUploadHeapSupported`.
- **`--no-upload-ahead`** — não envia texturas adiantadas; segura a VRAM.

### CPU

- **`VICTORY_FILL_WORKERS=6`** — threads de cópia de buffer. **O teto no código
  é 6**; subir no ambiente não faz nada.
- **`VICTORY_WIDE_WORKERS=12`** — threads de destile/hash de textura. Teto 12.
  O padrão do código é metade dos núcleos (3 em um 6c/12t).
- **`VICTORY_PIPELINE_WORKERS=8`** — threads de compilação de pipeline. Teto 12.
- **`VICTORY_PARALLEL_PRELUDES=1`** — grava os prelúdios de submissão em
  paralelo.
- **`VICTORY_WIDE_REFRESH=1`** — refreshes de cópia em paralelo.
- **`VICTORY_WIDE_BACK`** — snapshots paralelos. **Já vem ligado** por padrão;
  não é ganho novo.

### RAM — onde a build morre hoje

- **`VICTORY_INPLACE=1`** — em vez de copiar a memória do título para buffers
  do host, o runtime usa as páginas do próprio título no lugar. Corte medido:
  **3.250 MB → 2.326 MB** de cópias.
- **`VICTORY_INPLACE_MB=2048`** — teto do que fica emplaceado de uma vez.
  Em 32 GB, `4096` é o próximo teste.
- **`VICTORY_TEXTURE_BUDGET_MB=2600`** — teto das cópias de textura que o
  título preenche. Corte medido: **5.670 MB → 3.503 MB**.
- **`VICTORY_TEXTURE_ROOM_PERCENT=80`** — folga de VRAM antes de admitir cópias
  novas.
- **`VICTORY_CARD_WINDOWS_MB`** — manda as janelas de memória do título para a
  memória da placa em vez da RAM do sistema. Padrão `0`. É o próximo eixo de
  teste: as janelas eram 2,5 GB de RAM no pior instante.

## Present (a imagem na janela)

O título apresenta mais de uma *plane* por frame (a cena e a interface/vídeo).
O runtime percorre as planes, escolhe a de maior área e, se ela for menor que o
último alvo de desenho do frame, apresenta o último alvo — o fallback que tirou
a tela preta. `VICTORY_PRESENT_LAST_TARGET=0` desliga o fallback.

O swap chain acompanha o tamanho da textura apresentada. Com o
`VICTORY_DISPLAY_MODE` no tamanho da janela, ele para de ir para 4K.

## Teclado e mouse

O teclado e o mouse somam no pad 0 mesmo com um controle Xbox conectado.
WASD no stick esquerdo, mouse no stick direito, LMB = RT, RMB = LT, Espaço /
Enter = A, Ctrl / Backspace = B, Esc = Start, Tab = View. A tabela completa
está em [CONTROLES.md](CONTROLES.md).

## O crash do carregamento

Sai com `0x887A0005` e motivo `0x887A0001` no primeiro frame do mundo, sempre
entre 90 e 260 segundos. O DRED não dá breadcrumbs nesta máquina
(`0x887A0004`, sem suporte a page fault), então a causa foi medida pelos
contadores de memória, não pelo relatório do driver:

```
memory: 13376 MB private (7170 MB of it in memory; the PC has 344 MB free ...)
host copies of title memory: 3805 alive 2326 MB
host textures: 17879 alive 3503 MB
shared buffers: 3852 alive 2537 MB
```

O emulador guarda ~9 GB de cópias e o título emulado pede 7,7 GB. Em 16 GB não
cabe. O device removed é o fim da fila, não a causa.

O que **não** é a causa, já testado e descartado:

| hipótese | teste | resultado |
|---|---|---|
| VRAM | `VICTORY_TEXTURE_BUDGET_MB=3000` | morreu igual, com 3.871 MB de 7.256 MB |
| mesh shader | `VICTORY_MESH_TEST=skip` | morreu igual |
| corrida entre threads | `VICTORY_PIPELINE_WORKERS=1` | morreu igual |
| relay de submissões | `VICTORY_RELAY=0` + `VICTORY_LATE_WAIT=0` | morreu igual |
| sweep de memória | `VICTORY_SWEEP=0` | morreu igual |
| scissor | `VICTORY_MESH_TEST=scissor` | morreu igual |
| camada de validação | `VICTORY_D3D12_DEBUG=1` | zero erros D3D12 |

## Onde está o quê

- **Compilação** — `.cargo/config.toml` e `Cargo.toml`.
- **Runtime** — variáveis acima, no `GTA6.exe` e nos `.cmd`.
- **Imagem** — `crates/victory-gpu/src/queue.rs` (present) e `host.rs` (swap
  chain).
- **Input** — `crates/victory-hle/src/modules/gameinput.rs`.
- **Build reproduzível** — [BUILD-MAQUINA.md](BUILD-MAQUINA.md).

## Limites conhecidos

- O cap de 30 fps é do título; o override de 60 fps é experimental e pode
  acelerar a simulação se o jogo usar o intervalo pedido.
- 29 pipelines do título caem em `E_NOTIMPL` (FSR4 ACO). O título cai para
  "NewBE" sozinho; alguns efeitos podem faltar.
- O crash de RAM do carregamento é o bug aberto desta build.
- O relatório de crash fica em `state\7952987A\temp\*.crash.log` e
  `state\7952987A\crashes.log`.
