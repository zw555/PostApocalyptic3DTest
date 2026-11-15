param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
& (Join-Path $PSScriptRoot 'run_loot_tests.ps1') -GodotPath $GodotPath
if ($LASTEXITCODE -ne 0) {throw 'Regression failed'}
function Invoke-Stage4C([string]$Name,[string[]]$Arguments) {
    $logPath=Join-Path $PSScriptRoot ('results/'+$Name+'.log')
    & $GodotPath --path $projectPath --log-file $logPath @Arguments
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $logPath -Pattern '^(ERROR:|SCRIPT ERROR:)' -Quiet)) {throw "$Name failed"}
}
Invoke-Stage4C 'stage4c_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_loot_interaction.gd')
if ($Capture) {
    Invoke-Stage4C 'stage4c_capture' @('--script','res://tests/stage4c_capture.gd')
    Invoke-Stage4C 'stage4c_render_validation' @('--headless','--script','res://tests/verify_stage4c_render.gd')
}
Write-Output 'PASS Stage 4-C. Human acceptance PENDING.'
