param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture,[switch]$Regression)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resultPath=Join-Path $PSScriptRoot 'results'
function Invoke-D([string]$Name,[string[]]$Arguments) {
    $log=Join-Path $resultPath ($Name+'.log')
    & $GodotPath --path $projectPath --log-file $log @Arguments
    if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern '^(ERROR:|SCRIPT ERROR:|FAIL )' -Quiet)){throw "$Name failed"}
}
Invoke-D 'stage6a2d_import' @('--headless','--editor','--import')
foreach($script in @('scripts/apartment/floor5_connected_visibility.gd','scripts/apartment/floor5_player_peek.gd','scripts/apartment/floor5_player_peek_main.gd','tests/inspect_stage6a2d.gd','tests/validate_stage6a2d.gd','tests/capture_stage6a2d_views.gd')) {
    Invoke-D ('stage6a2d_parse_'+[IO.Path]::GetFileNameWithoutExtension($script)) @('--headless','--check-only','--script',('res://'+$script))
}
Invoke-D 'stage6a2d_smoke' @('--headless','--quit-after','120','res://scenes/apartment/stage6a2d_floor5.tscn')
Invoke-D 'stage6a2d_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage6a2d.gd')
$legacyError=$null
if($Regression) {
    try { & (Join-Path $PSScriptRoot 'run_stage6a2c_tests.ps1') -GodotPath $GodotPath -Regression }
    catch {$legacyError=$_.Exception.Message; Write-Output ('PRESERVED_OLD_GATE: '+$legacyError)}
}
if($Capture) {
    Invoke-D 'stage6a2d_render_validation' @('--fixed-fps','60','--script','res://tests/validate_stage6a2d.gd')
    Invoke-D 'stage6a2d_raster' @('--script','res://tests/capture_stage6a2d_views.gd')
}
@{focused=(Get-Content (Join-Path $resultPath 'stage6a2d_validation.json') -Raw|ConvertFrom-Json);capture_executed=[bool]$Capture;old_regressions_executed=[bool]$Regression;old_gate_error=$legacyError;human_acceptance='PENDING'}|ConvertTo-Json -Depth 12|Set-Content (Join-Path $resultPath 'stage6a2d_run_summary.json') -Encoding utf8
if($legacyError){throw 'D checks finished; original historical source-freeze gate remains nonzero.'}
