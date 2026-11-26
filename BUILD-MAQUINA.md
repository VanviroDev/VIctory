# Build desta maquina

Base: DexNom RayTime (fork do VIctory do Marvisak)
Pasta: `C:\Users\Administrator\Downloads\DexNom-RayTime`
Commit base: `64bd58f` + `a65d63a` (present multi-plane) + esta rodada
Estado: o jogo abre, mostra o logo, toca a intro e chega ao carregamento; o
carregamento ainda cai (crash em investigação). Ver `README.md`.

## O que foi mudado no codigo

1. `.cargo/config.toml`
   ```toml
   [target.x86_64-pc-windows-msvc]
   rustflags = ["-C", "target-cpu=znver3"]
   ```
   Ryzen 5 5600G = Zen 3 (Cezanne): AVX2 sim, AVX-512 nao. O binario usa znver3 direto.

2. `Cargo.toml`, `[profile.release]`
   ```toml
   lto = "fat"
   codegen-units = 1
   opt-level = 3
   ```
   Mantido `debug = "line-tables-only"` para o crash ainda nomear arquivo e linha.

## Rebuild

```powershell
$env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
cd C:\Users\Administrator\Downloads\DexNom-RayTime
cargo build --locked --release -p victory --features diagnostics --bins `
    --target x86_64-pc-windows-msvc --target-dir C:\vt
```

Binarios em `C:\vt\x86_64-pc-windows-msvc\release`:
`victory.exe`, `victory-play.exe`, `victory-warm.exe`.

Copiar os tres para `C:\GTA6-PC` e rodar `tools\pack\build.ps1` para gerar o
`GTA6.exe` unico (launcher + runtime + D3D12 + docs).

## Runtime

`C:\GTA6-PC` — a pasta inteira e portatil, pode ser movida ou copiada.
- `GTA6.exe` — launcher unico (extrai o runtime de dentro dele se faltar)
- `victory.exe`, `victory-play.exe`, `victory-warm.exe`
- `D3D12\D3D12Core.dll` — Agility SDK 1.620.2 (Shader Model 6.6)
- `game-path.txt` — caminho do `game_scarlett_master.exe` (UTF-8 sem BOM)
- `state` — saves
- `cache` — shaders e imagens traduzidas
- `logs\latest.txt` — aponta para o log da ultima execucao

## Perfis

| arquivo | console | RT | resolucao |
|---|---|---|---|
| `JOGAR-1080P.cmd` | series-s | off | nativa do Series S |
| `JOGAR-1440P.cmd` | series-x | off | cena 1080p -> saida 1440p |
| `AQUECER-CACHE.cmd` | — | — | traduz todos os shaders antes de jogar |

Variaveis comuns aos dois:

```
VICTORY_DISPLAY_MODE=1920x1080   (2560x1440 no perfil 1440p)
VICTORY_AMBIENT_FALLBACK=1
VICTORY_FSR_4K=0
VICTORY_FILL_WORKERS=6
VICTORY_WIDE_WORKERS=6
VICTORY_PARALLEL_PRELUDES=1
VICTORY_TEXTURE_BUDGET_MB=5200
VICTORY_TEXTURE_ROOM_PERCENT=80
VICTORY_LOG=warn
```

- `VICTORY_DISPLAY_MODE` — o titulo recebe o tamanho da janela em vez de
  assumir 4K. Maior economia de GPU/VRAM do conjunto.
- `VICTORY_TEXTURE_BUDGET_MB=5200` — teto das copias de textura do titulo.
  Sem ele o processo batia 7,2 GB de 7,2 GB da placa e o dispositivo era
  removido (o proprio codigo registra os runs 20 e 24).
- `VICTORY_TEXTURE_ROOM_PERCENT=80` — folga de VRAM antes de admitir novas
  copias.
- `VICTORY_FILL_WORKERS=6` / `VICTORY_WIDE_WORKERS=6` — 6 threads de copia e
  6 de destile/hash de textura (padrao do codigo: 3 num 6c/12t).
- `VICTORY_FRAME_INTERVAL=16667` — experimental, 60 fps; sem ela o runtime
  obedece o `set_interval(33333)` do titulo.

## Pagina de memoria

`C:\pagefile.sys` fixo em 40960 MB (40 GB), gerenciamento automatico desligado.
Vale depois do reboot: limite de commit passa de ~21 GB para ~56 GB.
O runtime pede ~33 GB de commit no mundo.

## Controles

Teclado e mouse viram um controle Xbox virtual quando nao ha controle fisico
conectado. Mapa completo, sensibilidade e como soltar o mouse: `CONTROLES.md`.

## Launcher

`tools/pack/GTA6.cs` compila com `tools/pack/build.ps1` (usa o `csc.exe` do
.NET Framework) para um unico `GTA6.exe` de ~19 MB: o runtime, o
`D3D12Core.dll`, o `CONTROLES.md` e este documento vao embutidos como
recursos. Na primeira execucao ele extrai o que falta na propria pasta, le o
`game-path.txt` e chama o `victory-play.exe`.

A janela tem JOGAR 1080p, JOGAR 1440p, Aquecer cache, Controles, Logs e Jogo
(troca a pasta do dump). Ela tambem restaura e foca a janela do titulo depois
de alguns segundos, para o jogo sair da tela de configuracao sem precisar de
controle. Sem janela: `GTA6.exe --play`, `GTA6.exe --play-1440p` ou
`GTA6.exe --install`.

## PresentX

O titulo apresenta duas planes; cada registro tem 0x48 bytes (token, contagem,
lista de recursos, reservados). O present percorre todas, escolhe a de maior
area e, quando ela esta vazia, mostra o alvo do ultimo draw do frame.
`VICTORY_PRESENT_LAST_TARGET=0` desliga esse substituto.
