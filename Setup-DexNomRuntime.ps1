[CmdletBinding()]
param(
    [string] $GamePath,
    [string] $InstallDir = (Join-Path $env:LOCALAPPDATA 'DexNom Runtime'),
    [string] $ShortcutDirectory = [Environment]::GetFolderPath('Programs'),
    [switch] $SkipBuild,
    [switch] $NoShortcuts
)

$ErrorActionPreference = 'Stop'

function Step($text) {
    Write-Host ""
    Write-Host ("==> " + $text) -ForegroundColor Cyan
}
function Note($text) { Write-Host ("    " + $text) -ForegroundColor DarkGray }

if ($env:OS -ne 'Windows_NT' -or ![Environment]::Is64BitOperatingSystem) {
    throw 'DexNom RayTime requires 64-bit Windows.'
}

# ---------------------------------------------------------------- tools
Step 'Checking the build tools'

$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
if (!(Get-Command cargo -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $cargoBin 'cargo.exe'))) {
    $env:Path = "$cargoBin;$env:Path"
}
if (!(Get-Command cargo -ErrorAction SilentlyContinue)) {
    throw 'Rust was not found. Install it from https://rustup.rs (or `winget install Rustlang.Rustup`), then open a new terminal and run Setup.cmd again.'
}
Note ("cargo: " + (& cargo --version))

if (!(Get-Command link.exe -ErrorAction SilentlyContinue)) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $found = $false
    if (Test-Path $vswhere) {
        $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
        if ($vs) {
            $vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
            if (Test-Path $vcvars) {
                $env:Path = (& cmd /c "`"$vcvars`" >nul && echo %PATH%") -join ''
                $found = $true
                Note ("Visual Studio: " + $vs)
            }
        }
    }
    if (!$found -and !(Get-Command link.exe -ErrorAction SilentlyContinue)) {
        throw 'link.exe was not found. Install Visual Studio 2022 Build Tools with the "Desktop development with C++" workload: winget install Microsoft.VisualStudio.2022.BuildTools'
    }
}
Note 'link.exe: ok'

# ---------------------------------------------------------------- game
Step 'Locating your game installation'

$InstallDir = [IO.Path]::GetFullPath($InstallDir)
for ($parent = [IO.DirectoryInfo]::new($InstallDir); $parent; $parent = $parent.Parent) {
    if (Test-Path -LiteralPath (Join-Path $parent.FullName '.victory-root')) {
        throw 'Choose an install directory outside the source checkout so the launcher can write saves and shader caches.'
    }
}
$config = Join-Path $InstallDir 'game-path.txt'
if (!$GamePath -and (Test-Path -LiteralPath $config -PathType Leaf)) {
    $saved = [IO.File]::ReadAllText($config).Trim()
    if ($saved -and (Test-Path -LiteralPath $saved -PathType Leaf)) { $GamePath = $saved }
}
if (!$GamePath) {
    Add-Type -AssemblyName System.Windows.Forms
    $picker = [Windows.Forms.OpenFileDialog]::new()
    try {
        $picker.Title = 'Select game_scarlett_master.exe from your extracted Xbox Series installation'
        $picker.Filter = 'Game executable (*.exe)|*.exe'
        if ($picker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) {
            Write-Host 'Setup cancelled.'
            return
        }
        $GamePath = $picker.FileName
    } finally { $picker.Dispose() }
}
$game = Get-Item -LiteralPath $GamePath
if ($game.PSIsContainer -or $game.Extension -ine '.exe') {
    throw 'Select the game executable in its original installation directory.'
}
Note $game.FullName

# ---------------------------------------------------------------- agility sdk
Step 'Checking the Direct3D 12 Agility SDK'

$sdkVersion = '1.620.2'
$sdkDir = Join-Path $PSScriptRoot 'D3D12'
$sdkCore = Join-Path $sdkDir 'D3D12Core.dll'
if (!(Test-Path -LiteralPath $sdkCore)) {
    Note "D3D12Core.dll not found; downloading Agility SDK $sdkVersion from nuget.org"
    $package = Join-Path $env:TEMP "microsoft.direct3d.d3d12.$sdkVersion.nupkg"
    $url = "https://api.nuget.org/v3-flatcontainer/microsoft.direct3d.d3d12/$sdkVersion/microsoft.direct3d.d3d12.$sdkVersion.nupkg"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $package -UseBasicParsing -TimeoutSec 300
    } catch {
        throw "Could not download the Agility SDK. Download $url yourself, open it as a zip, and copy build\native\bin\x64\D3D12Core.dll and d3d12SDKLayers.dll into $sdkDir. ($($_.Exception.Message))"
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Directory]::CreateDirectory($sdkDir) | Out-Null
    $zip = [IO.Compression.ZipFile]::OpenRead($package)
    try {
        foreach ($name in 'D3D12Core.dll', 'd3d12SDKLayers.dll') {
            $entry = $zip.Entries | Where-Object { $_.FullName -eq "build/native/bin/x64/$name" } | Select-Object -First 1
            if (!$entry) { throw "The Agility SDK package does not contain $name." }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $sdkDir $name), $true)
        }
    } finally { $zip.Dispose() }
    Remove-Item $package -ErrorAction SilentlyContinue
}
$coreVersion = (Get-Item $sdkCore).VersionInfo.FileVersion
if ($coreVersion -notlike '1.620.*') {
    throw "D3D12Core.dll is $coreVersion, but the runtime declares SDK 620. Replace $sdkCore with the 1.620.2 build."
}
Note "D3D12Core.dll $coreVersion"

# ---------------------------------------------------------------- build
if (!$SkipBuild) {
    Step 'Building the runtime (10 to 20 minutes the first time)'
    Push-Location -LiteralPath $PSScriptRoot
    try {
        & (Join-Path $PSScriptRoot 'Initialize-FormatTables.ps1')
        $targetDir = Join-Path $PSScriptRoot 'target'
        $target = 'x86_64-pc-windows-msvc'
        & cargo build --locked --release -p victory --features diagnostics --bins --target $target --target-dir $targetDir
        if ($LASTEXITCODE -ne 0) {
            throw 'Build failed. Check the compiler output and the C++ workload and Windows SDK listed in the README.'
        }
        $release = Join-Path $targetDir "$target/release"
        & (Join-Path $release 'victory.exe') inspect $game.FullName | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'The runtime could not read the selected game executable.' }
    } finally { Pop-Location }
} else {
    Step 'Skipping the build'
    $target = 'x86_64-pc-windows-msvc'
    $release = Join-Path (Join-Path $PSScriptRoot 'target') "$target/release"
}
$release = Join-Path (Join-Path $PSScriptRoot 'target') "$target/release"
if (!(Test-Path (Join-Path $release 'victory.exe'))) {
    throw "No build found in $release. Run Setup.cmd without -SkipBuild."
}

# ---------------------------------------------------------------- install
Step "Installing into $InstallDir"

$state = [IO.Directory]::CreateDirectory((Join-Path $InstallDir 'state'))
try {
    $lock = [IO.File]::Open((Join-Path $state.FullName 'launcher.lock'), 'OpenOrCreate', 'Write', 'None')
} catch [IO.IOException] {
    throw "Could not lock the install directory. Close DexNom RayTime and shader preload before updating. $($_.Exception.Message)"
}
try {
    foreach ($name in 'victory.exe', 'victory-play.exe', 'victory-warm.exe') {
        $destination = Join-Path $InstallDir $name
        $temp = Join-Path $InstallDir ([IO.Path]::GetRandomFileName())
        try {
            [IO.File]::Copy((Join-Path $release $name), $temp)
            if ([IO.File]::Exists($destination)) {
                [IO.File]::Replace($temp, $destination, [System.Management.Automation.Language.NullString]::Value)
            } else {
                [IO.File]::Move($temp, $destination)
            }
        } finally { if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) } }
    }
    # The Agility SDK must sit in D3D12\ beside victory.exe: the binary exports
    # D3D12SDKPath = ".\D3D12\" and the system d3d12.dll looks there.
    $installSdk = Join-Path $InstallDir 'D3D12'
    [IO.Directory]::CreateDirectory($installSdk) | Out-Null
    foreach ($name in 'D3D12Core.dll', 'd3d12SDKLayers.dll') {
        $from = Join-Path $sdkDir $name
        if (Test-Path -LiteralPath $from) { [IO.File]::Copy($from, (Join-Path $installSdk $name), $true) }
    }
    [IO.File]::WriteAllText($config, $game.FullName, [Text.UTF8Encoding]::new($false))
    foreach ($doc in 'README.md', 'OTIMIZACOES.md', 'CONTROLES.md', 'BUILD-MAQUINA.md') {
        $from = Join-Path $PSScriptRoot $doc
        if (Test-Path -LiteralPath $from) { [IO.File]::Copy($from, (Join-Path $InstallDir $doc), $true) }
    }
    foreach ($script in 'VERIFICAR.ps1', 'VERIFICAR.cmd') {
        $from = Join-Path $PSScriptRoot $script
        if (Test-Path -LiteralPath $from) { [IO.File]::Copy($from, (Join-Path $InstallDir $script), $true) }
    }
} finally { $lock.Dispose() }

# ---------------------------------------------------------------- launchers
Step 'Writing the launch scripts'

$profiles = @(
    @{ File = 'JOGAR-1080P.cmd';   Name = 'DexNom RayTime (1080p)';        Console = 'series-s'; Extra = ''; Display = '1920x1080'; Budget = '2600'; Inplace = '2048'; Room = '80';  Log = 'warn'; Text = '1080p - Series S, sem ray tracing' }
    @{ File = 'JOGAR-1440P.cmd';   Name = 'DexNom RayTime (1440p)';        Console = 'series-x'; Extra = '--1080p-to-1440p'; Display = '2560x1440'; Budget = '3600'; Inplace = '3072'; Room = '85'; Log = 'warn'; Text = '1440p - Series X, cena em 1080p' }
    @{ File = 'JOGAR-DIAGNOSTICO.cmd'; Name = 'DexNom RayTime (diagnostico)'; Console = 'series-s'; Extra = ''; Display = '1920x1080'; Budget = '2600'; Inplace = '2048'; Room = '80'; Log = 'info'; Text = '1080p com log detalhado, copia o log para a Area de Trabalho' }
)

foreach ($p in $profiles) {
    $lines = @(
        '@echo off'
        'setlocal EnableExtensions EnableDelayedExpansion'
        "rem Gerado por Setup.cmd - $($p.Text)"
        'set "RUNTIME=%~dp0"'
        'if not exist "%RUNTIME%victory-play.exe" ('
        '    echo Faltam os binarios. Rode Setup.cmd de novo.'
        '    pause'
        '    exit /b 1'
        ')'
        'if not exist "%RUNTIME%game-path.txt" ('
        '    echo Falta o game-path.txt. Rode Setup.cmd e aponte para o jogo.'
        '    pause'
        '    exit /b 1'
        ')'
        ''
        "set `"VICTORY_DISPLAY_MODE=$($p.Display)`""
        'set "VICTORY_FRAME_INTERVAL=16667"'
        'set "VICTORY_FSR_4K=0"'
        'set "VICTORY_AMBIENT_FALLBACK=1"'
        'set "VICTORY_FILL_WORKERS=6"'
        'set "VICTORY_WIDE_WORKERS=12"'
        'set "VICTORY_PIPELINE_WORKERS=8"'
        'set "VICTORY_PARALLEL_PRELUDES=1"'
        'set "VICTORY_WIDE_REFRESH=1"'
        'set "VICTORY_INDIRECT_WINDOW=1"'
        'set "VICTORY_INPLACE=1"'
        "set `"VICTORY_INPLACE_MB=$($p.Inplace)`""
        "set `"VICTORY_TEXTURE_BUDGET_MB=$($p.Budget)`""
        "set `"VICTORY_TEXTURE_ROOM_PERCENT=$($p.Room)`""
        "set `"VICTORY_LOG=$($p.Log)`""
        ''
        "`"%RUNTIME%victory-play.exe`" --no-rt --console $($p.Console) $($p.Extra) --local-gpu-memory --sparse-textures --no-upload-ahead".Replace('  ', ' ')
        'set "CODE=%ERRORLEVEL%"'
        'if "%VICTORY_LOG%"=="info" ('
        '    set "STAMP=%DATE:~-4%%DATE:~3,2%%DATE:~0,2%-%TIME:~0,2%%TIME:~3,2%"'
        '    set "STAMP=!STAMP: =0!"'
        '    if exist "%RUNTIME%logs\latest.txt" copy /y "%RUNTIME%logs\latest.txt" "%USERPROFILE%\Desktop\dexnom-log-!STAMP!.txt" >nul'
        '    echo.'
        '    echo Log copiado para a Area de Trabalho: dexnom-log-!STAMP!.txt'
        '    echo Anexe esse arquivo na issue, junto da saida do VERIFICAR.cmd.'
        ')'
        'if not "%CODE%"=="0" ('
        '    echo.'
        '    echo Runtime terminou com codigo %CODE%.'
        '    echo Log: %RUNTIME%logs\latest.txt'
        '    pause'
        ')'
        'exit /b %CODE%'
    )
    $text = ($lines -join "`r`n") + "`r`n"
    [IO.File]::WriteAllText((Join-Path $InstallDir $p.File), $text, [Text.ASCIIEncoding]::new())
}
Note 'JOGAR-1080P.cmd, JOGAR-1440P.cmd, JOGAR-DIAGNOSTICO.cmd'

# ---------------------------------------------------------------- shortcuts
if (!$NoShortcuts) {
    Step 'Creating Start Menu shortcuts'
    [IO.Directory]::CreateDirectory($ShortcutDirectory) | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    foreach ($p in $profiles) {
        $shortcut = $shell.CreateShortcut((Join-Path $ShortcutDirectory ($p.Name + '.lnk')))
        $shortcut.TargetPath = Join-Path $InstallDir $p.File
        $shortcut.WorkingDirectory = $InstallDir
        $shortcut.Description = "DexNom RayTime - $($p.Text)"
        $shortcut.Save()
    }
    Note $ShortcutDirectory
}

Write-Host ""
Write-Host 'Pronto.' -ForegroundColor Green
Write-Host "  Instalado em: $InstallDir"
Write-Host "  Jogo:         $($game.FullName)"
Write-Host ''
Write-Host '  Jogar:        JOGAR-1080P.cmd na pasta de instalacao, ou o atalho no menu Iniciar'
Write-Host '  Conferir:     VERIFICAR.cmd'
Write-Host '  Diagnostico:  JOGAR-DIAGNOSTICO.cmd (log detalhado para anexar em issue)'
Write-Host ''
Write-Host 'O primeiro boot traduz shaders e converte texturas; leva minutos.' -ForegroundColor DarkGray
