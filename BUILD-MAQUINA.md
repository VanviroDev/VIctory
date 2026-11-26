# Build desta maquina

Base: DexNom RayTime (fork do VIctory do Marvisak)
Pasta: `C:\Users\Administrator\Downloads\DexNom-RayTime`
Commit: 64bd58f (2026-11-25)

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

Copiar os tres para `%LOCALAPPDATA%\DexNom Runtime`.

## Runtime

`%LOCALAPPDATA%\DexNom Runtime`
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
`VICTORY_AMBIENT_FALLBACK=1` (luz ambiente no lugar do RT),
`VICTORY_FSR_4K=0`,
`VICTORY_FILL_WORKERS=4` e `VICTORY_PARALLEL_PRELUDES=1` (6 nucleos / 12 threads).

## Pagina de memoria

`C:\pagefile.sys` fixo em 40960 MB (40 GB), gerenciamento automatico desligado.
Vale depois do reboot: limite de commit passa de ~21 GB para ~56 GB.
O runtime pede ~33 GB de commit no mundo.
