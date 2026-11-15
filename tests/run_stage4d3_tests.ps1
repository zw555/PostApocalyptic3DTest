param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
# Logic and asset regressions remain applicable. Historical camera-matrix image
# comparisons from D.1/D.2 intentionally use the old off-center composition.
& (Join-Path $PSScriptRoot 'run_stage4d2_tests.ps1') -GodotPath $GodotPath
if ($LASTEXITCODE -ne 0) {throw 'Previous logic/asset regression failed'}
function Invoke-D3([string]$Name,[string[]]$Arguments) {
    $logPath=Join-Path $PSScriptRoot ('results/'+$Name+'.log')
    & $GodotPath --path $projectPath --log-file $logPath @Arguments
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $logPath -Pattern '^(ERROR:|SCRIPT ERROR:)' -Quiet)) {throw "$Name failed"}
}
Invoke-D3 'stage4d3_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_camera_presets.gd')
if ($Capture) {
    Invoke-D3 'stage4d3_capture' @('--script','res://tests/stage4d3_capture.gd')
    Invoke-D3 'stage4d3_render_validation' @('--headless','--script','res://tests/verify_stage4d3_render.gd')
}
Write-Output 'PASS Stage 4-D.3; human acceptance PENDING.'
