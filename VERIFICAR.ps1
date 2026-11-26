[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$script:fail = 0
$script:warn = 0

function Ok($what, $detail) {
    Write-Host ("  [ OK ]  {0}" -f $what) -ForegroundColor Green
    if ($detail) { Write-Host ("          {0}" -f $detail) -ForegroundColor DarkGray }
}
function Warn($what, $detail, $fix) {
    $script:warn++
    Write-Host ("  [AVISO] {0}" -f $what) -ForegroundColor Yellow
    if ($detail) { Write-Host ("          {0}" -f $detail) -ForegroundColor DarkGray }
    if ($fix) { Write-Host ("          -> {0}" -f $fix) -ForegroundColor Yellow }
}
function Bad($what, $detail, $fix) {
    $script:fail++
    Write-Host ("  [FALHA] {0}" -f $what) -ForegroundColor Red
    if ($detail) { Write-Host ("          {0}" -f $detail) -ForegroundColor DarkGray }
    if ($fix) { Write-Host ("          -> {0}" -f $fix) -ForegroundColor Red }
}
function Section($name) {
    Write-Host ""
    Write-Host $name -ForegroundColor Cyan
    Write-Host ("-" * $name.Length) -ForegroundColor DarkCyan
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$installed = Test-Path (Join-Path $root 'victory.exe')
Write-Host ""
Write-Host "DexNom RayTime - verificacao da maquina" -ForegroundColor White
Write-Host "pasta: $root" -ForegroundColor DarkGray

# ---------------------------------------------------------------- Windows
Section "Sistema"

$os = Get-CimInstance Win32_OperatingSystem
$build = [int]$os.BuildNumber
if ([Environment]::Is64BitOperatingSystem) {
    Ok "Windows x64" ("{0} build {1}" -f $os.Caption, $build)
} else {
    Bad "Windows x64" "este processo e de 32 bits" "instale o Windows x64"
}
if ($build -ge 19045) {
    Ok "build do Windows" "19045 ou mais novo"
} else {
    Warn "build do Windows antigo" ("build {0}, o minimo testado e 19045" -f $build) "atualize o Windows 10"
}

$ramMb = [math]::Round($os.TotalVisibleMemorySize / 1024)
if ($ramMb -ge 30000) {
    Ok "memoria RAM" ("{0:N0} MB - folga confortavel" -f $ramMb)
} elseif ($ramMb -ge 15000) {
    Warn "memoria RAM no limite" ("{0:N0} MB - 16 GB e o minimo, o carregamento morre por RAM" -f $ramMb) "leia a secao 'O crash do carregamento' no README"
} else {
    Bad "memoria RAM insuficiente" ("{0:N0} MB" -f $ramMb) "16 GB e o minimo; 32 GB e o recomendado"
}

$pf = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue
if ($pf) {
    $pfMb = ($pf | Measure-Object -Property AllocatedBaseSize -Sum).Sum
    if ($pfMb -ge 8000) { Ok "arquivo de paginacao" ("{0:N0} MB" -f $pfMb) }
    else { Warn "arquivo de paginacao pequeno" ("{0:N0} MB" -f $pfMb) "deixe o Windows gerenciar ou use 16 GB" }
} else {
    Warn "sem arquivo de paginacao" "o commit fica limitado a RAM fisica" "ative a paginacao gerenciada pelo sistema"
}

$disk = Get-PSDrive -Name ($root.Substring(0, 1)) -ErrorAction SilentlyContinue
if ($disk) {
    $freeGb = [math]::Round($disk.Free / 1GB, 1)
    if ($freeGb -ge 10) { Ok "espaco em disco" ("{0} GB livres" -f $freeGb) }
    else { Warn "pouco espaco em disco" ("{0} GB livres; o cache de shaders e texturas cresce" -f $freeGb) "libere 10 GB" }
}

# ---------------------------------------------------------------- CPU
Section "Processador"

$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
Ok "CPU" ("{0} - {1} nucleos / {2} threads" -f $cpu.Name.Trim(), $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors)

$configToml = Join-Path $root '.cargo\config.toml'
$targetCpu = $null
if (Test-Path $configToml) {
    $m = Select-String -Path $configToml -Pattern 'target-cpu=([A-Za-z0-9_-]+)' | Select-Object -First 1
    if ($m) { $targetCpu = $m.Matches[0].Groups[1].Value }
}
if ($targetCpu) {
    $name = $cpu.Name
    $isZen3Plus = $name -match '5[6-9][0-9]{2}|7[0-9]{3}|9[0-9]{3}|Ryzen 5 3[6-9][0-9]{2}|Ryzen 7 5[7-9][0-9]{2}|EPYC 7[0-9]{2}'
    if ($targetCpu -eq 'znver3' -and -not $isZen3Plus) {
        Warn "binario compilado para znver3" ("seu CPU: {0}" -f $name) "troque para native em .cargo/config.toml e rode Setup.cmd de novo"
    } else {
        Ok "alvo de compilacao" ("target-cpu={0}" -f $targetCpu)
    }
} else {
    if ($installed) { Ok "alvo de compilacao" "copia instalada - o binario ja foi compilado" }
    else { Ok "alvo de compilacao" "padrao (sem target-cpu fixo)" }
}

# ---------------------------------------------------------------- Ferramentas
Section "Ferramentas de build"

$cargo = Get-Command cargo -ErrorAction SilentlyContinue
if (-not $cargo) {
    $cargoExe = Join-Path $env:USERPROFILE '.cargo\bin\cargo.exe'
    if (Test-Path $cargoExe) {
        Warn "cargo fora do PATH" $cargoExe "adicione %USERPROFILE%\.cargo\bin ao PATH e reabra o terminal"
        $cargo = $cargoExe
    }
}
if ($cargo) {
    $ver = (& $cargo --version) 2>$null
    Ok "cargo" $ver
    $rustc = Get-Command rustc -ErrorAction SilentlyContinue
    if ($rustc) {
        $rustcVer = (& rustc --version) 2>$null
        if ($rustcVer -match '(\d+)\.(\d+)') {
            $maj = [int]$Matches[1]; $min = [int]$Matches[2]
            if ($maj -gt 1 -or ($maj -eq 1 -and $min -ge 85)) { Ok "rustc" $rustcVer }
            else { Bad "rustc antigo" $rustcVer "rustup update stable" }
        }
    }
} elseif ($installed) {
    Ok "cargo" "nao instalado - nao e preciso para jogar, so para compilar"
} else {
    Bad "cargo nao encontrado" "Rust nao esta no PATH" "winget install Rustlang.Rustup, depois reabra o terminal"
}

$link = Get-Command link.exe -ErrorAction SilentlyContinue
if (-not $link) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
        if ($vs) {
            $cand = Join-Path $vs 'VC\Tools\MSVC'
            if (Test-Path $cand) {
                $link = Get-ChildItem $cand -Recurse -Filter link.exe -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -match 'Hostx64\\x64' } | Select-Object -First 1
            }
        }
    }
}
if ($link) {
    $linkPath = $link.Source
    if (-not $linkPath) { $linkPath = $link.FullName }
    Ok "link.exe" $linkPath
} else {
    Bad "link.exe nao encontrado" "Build Tools sem o workload de C++" "winget install Microsoft.VisualStudio.2022.BuildTools e marque 'Desktop development with C++'"
}

# ---------------------------------------------------------------- GPU
Section "Placa de video"

$gpus = Get-CimInstance Win32_VideoController
foreach ($g in $gpus) {
    $drv = $g.DriverVersion
    $date = if ($g.DriverDate) { ([datetime]$g.DriverDate).ToString('yyyy-MM-dd') } else { '?' }
    if ($g.Name -match 'Basic Display|Basic Render') { continue }
    Ok $g.Name ("driver {0} de {1}, {2:N0} MB de VRAM reportados" -f $drv, $date, ($g.AdapterRAM / 1MB))
    if ($g.DriverDate -and ([datetime]$g.DriverDate) -lt (Get-Date).AddYears(-2)) {
        Warn "driver antigo" ("{0}" -f $g.DriverDate) "atualize o driver da placa"
    }
}
if (-not ($gpus | Where-Object { $_.Name -notmatch 'Basic' })) {
    Bad "nenhuma placa D3D12 encontrada" "" "instale o driver da placa"
}

# ---------------------------------------------------------------- Runtime
Section "Runtime"

$exe = Join-Path $root 'victory.exe'
$play = Join-Path $root 'victory-play.exe'
$warm = Join-Path $root 'victory-warm.exe'
$core = Join-Path $root 'D3D12\D3D12Core.dll'

foreach ($f in @($exe, $play, $warm)) {
    if (Test-Path $f) { Ok (Split-Path $f -Leaf) ("{0:N1} MB" -f ((Get-Item $f).Length / 1MB)) }
    else { Bad ((Split-Path $f -Leaf) + " ausente") "" "rode Setup.cmd ou copie de target\x86_64-pc-windows-msvc\release" }
}
if (Test-Path $core) {
    $vi = (Get-Item $core).VersionInfo
    Ok "D3D12Core.dll (Agility SDK)" ("versao {0}" -f $vi.FileVersion)
} else {
    Bad "D3D12Core.dll ausente" "o runtime declara SDK 620 e procura em D3D12\" "rode Setup.cmd; o arquivo vem do repositorio"
}

$gp = Join-Path $root 'game-path.txt'
if (Test-Path $gp) {
    $bytes = [IO.File]::ReadAllBytes($gp)
    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $path = [IO.File]::ReadAllText($gp).Trim()
    if ($bom) {
        Warn "game-path.txt com BOM" "o runtime le o arquivo como UTF-8 sem BOM" "salve de novo como UTF-8 sem BOM, ou rode Setup.cmd"
    } elseif (Test-Path -LiteralPath $path) {
        Ok "jogo" $path
    } else {
        Bad "caminho do jogo nao existe" $path "rode Setup.cmd e aponte para game_scarlett_master.exe"
    }
} else {
    Bad "game-path.txt ausente" "" "rode Setup.cmd"
}

# ---------------------------------------------------------------- Resultado
Write-Host ""
if ($script:fail -eq 0 -and $script:warn -eq 0) {
    Write-Host "Tudo pronto. Rode JOGAR-1080P.cmd." -ForegroundColor Green
} elseif ($script:fail -eq 0) {
    Write-Host ("Pronto para rodar, com {0} aviso(s). Rode JOGAR-1080P.cmd." -f $script:warn) -ForegroundColor Yellow
} else {
    Write-Host ("{0} falha(s) e {1} aviso(s). Resolva as falhas e rode de novo." -f $script:fail, $script:warn) -ForegroundColor Red
}
Write-Host ""
Write-Host "Se o jogo cair no carregamento, anexe logs\latest.txt na issue." -ForegroundColor DarkGray
Write-Host ""
if ($Host.Name -eq 'ConsoleHost' -and -not $env:DEXNOM_NO_PAUSE) {
    Read-Host "Enter para fechar" | Out-Null
}
