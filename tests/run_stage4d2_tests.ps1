param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
& (Join-Path $PSScriptRoot 'run_stage4d1_tests.ps1') -GodotPath $GodotPath -Capture:$Capture
if ($LASTEXITCODE -ne 0) {throw 'Previous regression failed'}
function Invoke-D2([string]$Name,[string[]]$Arguments) {
    $logPath=Join-Path $PSScriptRoot ('results/'+$Name+'.log')
    & $GodotPath --path $projectPath --log-file $logPath @Arguments
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $logPath -Pattern '^(ERROR:|SCRIPT ERROR:)' -Quiet)) {throw "$Name failed"}
}
Invoke-D2 'stage4d2_validation' @('--headless','--script','res://tests/validate_art_localization.gd')
Invoke-D2 'stage4d2_export' @('--headless','--export-pack','Wangjia Resource Validation','tests/results/wangjia_resources.pck')
$probePath=Join-Path $PSScriptRoot 'results/packed_probe'
New-Item -ItemType Directory -Force -Path $probePath | Out-Null
$packedLog=Join-Path $PSScriptRoot 'results/stage4d2_packed_smoke.log'
Push-Location $probePath
try {
    & $GodotPath --headless --main-pack (Join-Path $PSScriptRoot 'results/wangjia_resources.pck') --script res://scripts/localization/verify_export.gd --log-file $packedLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $packedLog -Pattern '^(ERROR:|SCRIPT ERROR:)' -Quiet)) {throw 'Packed resources failed'}
} finally { Pop-Location }
if ($Capture) {
    Invoke-D2 'stage4d_visual_regression_capture' @('--script','res://tests/stage4d_capture.gd')
    Invoke-D2 'stage4d_visual_regression_validation' @('--headless','--script','res://tests/verify_stage4d_render.gd')
    Invoke-D2 'stage4d2_capture' @('--script','res://tests/stage4d2_capture.gd')
    Invoke-D2 'stage4d2_render_validation' @('--headless','--script','res://tests/verify_stage4d2_render.gd')
}
Write-Output 'PASS Stage 4-D.2. Human acceptance PENDING.'
