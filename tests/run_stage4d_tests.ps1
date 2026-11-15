param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
# Stage 4-B/4-C single-shelf quantities are obsolete; preserve their test scripts.
& (Join-Path $PSScriptRoot 'run_cad_tests.ps1') -GodotPath $GodotPath
if ($LASTEXITCODE -ne 0) {throw 'CAD regression failed'}
function Invoke-Store([string]$Name,[string[]]$Arguments) {
    $logPath=Join-Path $PSScriptRoot ('results/'+$Name+'.log')
    & $GodotPath --path $projectPath --log-file $logPath @Arguments
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $logPath -Pattern '^(ERROR:|SCRIPT ERROR:)' -Quiet)) {throw "$Name failed"}
}
Invoke-Store 'stage4d_smoke' @('--headless','--quit-after','60','res://scenes/looted_convenience_store.tscn')
Invoke-Store 'stage4d_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_store_loot.gd')
if ($Capture) {
    Invoke-Store 'stage4d_capture' @('--script','res://tests/stage4d_capture.gd')
    Invoke-Store 'stage4d_render_validation' @('--headless','--script','res://tests/verify_stage4d_render.gd')
}
Write-Output 'PASS Stage 4-D; human acceptance PENDING.'
