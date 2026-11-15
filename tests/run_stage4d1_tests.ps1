param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
& (Join-Path $PSScriptRoot 'run_stage4d_tests.ps1') -GodotPath $GodotPath
if ($LASTEXITCODE -ne 0) {throw 'Stage 4-D regression failed'}
function Invoke-D1([string]$Name,[string[]]$Arguments) {
    $logPath=Join-Path $PSScriptRoot ('results/'+$Name+'.log')
    & $GodotPath --path $projectPath --log-file $logPath @Arguments
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $logPath -Pattern '^(ERROR:|SCRIPT ERROR:)' -Quiet)) {throw "$Name failed"}
}
Invoke-D1 'stage4d1_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_scarcity_highlight.gd')
if ($Capture) {
    Invoke-D1 'stage4d1_capture' @('--script','res://tests/stage4d1_capture.gd')
    Invoke-D1 'stage4d1_extra_capture' @('--script','res://tests/capture_d1_extra.gd')
    Invoke-D1 'stage4d1_render_validation' @('--headless','--script','res://tests/verify_stage4d1_render.gd')
}
Write-Output 'PASS Stage 4-D.1; human acceptance PENDING.'
