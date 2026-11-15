param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
& (Join-Path $PSScriptRoot 'run_stage5a_tests.ps1') -GodotPath $GodotPath -Capture:$Capture
if ($LASTEXITCODE -ne 0) {throw 'Previous regression failed'}
function Invoke-5B([string]$Name,[string[]]$Arguments) {
    $logPath=Join-Path $PSScriptRoot ('results/'+$Name+'.log')
    & $GodotPath --path $projectPath --log-file $logPath @Arguments
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $logPath -Pattern '^(ERROR:|SCRIPT ERROR:)' -Quiet)) {throw "$Name failed"}
}
Invoke-5B 'stage5b_smoke' @('--headless','--quit-after','120','res://scenes/zombie_chase_validation.tscn')
Invoke-5B 'stage5b_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_zombie_ai.gd')
if ($Capture) {
    Invoke-5B 'stage5b_render' @('--script','res://tests/stage5b_capture.gd')
}
Write-Output 'PASS Stage 5-B automated validation. Human acceptance A-G PENDING.'
