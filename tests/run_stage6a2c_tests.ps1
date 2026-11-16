param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture,[switch]$Regression)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resultPath=Join-Path $PSScriptRoot 'results'
function Invoke-C([string]$Name,[string[]]$Arguments) {
    $log=Join-Path $resultPath ($Name+'.log')
    & $GodotPath --path $projectPath --log-file $log @Arguments
    if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern '^(ERROR:|SCRIPT ERROR:|FAIL )' -Quiet)){throw "$Name failed"}
}
Invoke-C 'stage6a2c_import' @('--headless','--editor','--import')
foreach($script in @('scripts/apartment/floor5_main.gd','scripts/apartment/floor5_safe_door.gd','scripts/apartment/floor5_connected_builder.gd','scripts/apartment/floor5_connected_visibility.gd','scripts/apartment/floor5_connected_main.gd','tests/validate_stage6a2c.gd','tests/inspect_stage6a2c.gd','tests/capture_stage6a2c.gd','tests/check_stage6a2c_images.gd','tests/run_stage6a2c_low_physics.gd')) {
    Invoke-C ('stage6a2c_parse_'+[IO.Path]::GetFileNameWithoutExtension($script)) @('--headless','--check-only','--script',('res://'+$script))
}
Invoke-C 'stage6a2c_smoke' @('--headless','--quit-after','120','res://scenes/apartment/stage6a2c_floor5.tscn')
Invoke-C 'stage6a2c_low_physics_smoke' @('--headless','--quit-after','30','--script','res://tests/run_stage6a2c_low_physics.gd')
Invoke-C 'stage6a2c_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage6a2c.gd')
$legacyError=$null
if($Regression) {
    try { & (Join-Path $PSScriptRoot 'run_stage6a2b_regions_tests.ps1') -GodotPath $GodotPath -Regression }
    catch {$legacyError=$_.Exception.Message; Write-Output ('PRESERVED_OLD_GATE: '+$legacyError)}
}
if($Capture) {
    Invoke-C 'stage6a2c_render_validation' @('--fixed-fps','60','--script','res://tests/validate_stage6a2c.gd')
    Invoke-C 'stage6a2c_capture' @('--script','res://tests/capture_stage6a2c.gd')
    Invoke-C 'stage6a2c_pixel_validation' @('--headless','--script','res://tests/check_stage6a2c_images.gd')
}
@{focused=(Get-Content (Join-Path $resultPath 'stage6a2c_validation.json') -Raw|ConvertFrom-Json);capture_executed=[bool]$Capture;old_regressions_executed=[bool]$Regression;old_gate_error=$legacyError;human_acceptance='PENDING'}|ConvertTo-Json -Depth 12|Set-Content (Join-Path $resultPath 'stage6a2c_run_summary.json') -Encoding utf8
if($legacyError){throw 'C checks finished; preserved historical source-freeze gate remains nonzero.'}
