# Monta o GTA6.exe unico: launcher + runtime + Agility SDK + docs.
# Uso: .\build.ps1 [-Out <pasta>]
param(
    [string]$Out = ("C:\GTA6-PC")
)
$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$release = Join-Path $root "target\release"
$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$d3d = "C:\GTA6-PC\D3D12\D3D12Core.dll"

foreach ($file in @("$release\victory.exe", "$release\victory-play.exe", "$release\victory-warm.exe", $d3d, "$root\CONTROLES.md", "$root\BUILD-MAQUINA.md", "$root\OTIMIZACOES.md")) {
    if (-not (Test-Path $file)) { throw "Falta $file" }
}

New-Item -ItemType Directory -Force -Path $Out | Out-Null
$target = Join-Path $Out "GTA6.exe"

& $csc /nologo /target:winexe /codepage:65001 /out:"$target" `
    /reference:System.dll /reference:System.Core.dll `
    /reference:System.Windows.Forms.dll /reference:System.Drawing.dll `
    "/resource:$release\victory.exe,victory.exe" `
    "/resource:$release\victory-play.exe,victory-play.exe" `
    "/resource:$release\victory-warm.exe,victory-warm.exe" `
    "/resource:$d3d,D3D12Core.dll" `
    "/resource:$root\CONTROLES.md,CONTROLES.md" `
    "/resource:$root\BUILD-MAQUINA.md,BUILD-MAQUINA.md" `
    "/resource:$root\OTIMIZACOES.md,OTIMIZACOES.md" `
    "$PSScriptRoot\GTA6.cs"

if ($LASTEXITCODE -ne 0) { throw "csc falhou com codigo $LASTEXITCODE" }
Write-Host "GTA6.exe -> $target ($([math]::Round((Get-Item $target).Length / 1MB, 1)) MB)"
