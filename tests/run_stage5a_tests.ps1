param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
# Historical preset capture is still exercised; no old checks are waived.
& (Join-Path $PSScriptRoot 'run_stage4d3_tests.ps1') -GodotPath $GodotPath -Capture:$Capture
if ($LASTEXITCODE -ne 0) {throw 'Previous regression failed'}
function Invoke-5A([string]$Name,[string[]]$Arguments) {
    $logPath=Join-Path $PSScriptRoot ('results/'+$Name+'.log')
    & $GodotPath --path $projectPath --log-file $logPath @Arguments
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $logPath -Pattern '^(ERROR:|SCRIPT ERROR:)' -Quiet)) {throw "$Name failed"}
}
Invoke-5A 'stage5a_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_player_occlusion.gd')
if ($Capture) {
    Invoke-5A 'stage5a_render' @('--script','res://tests/stage5a_capture.gd')
}
Write-Output 'PASS Stage 5-A automated checks. Human acceptance A-F PENDING.'
