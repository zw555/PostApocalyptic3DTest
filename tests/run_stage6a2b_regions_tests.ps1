param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture,[switch]$Regression)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resultPath=Join-Path $PSScriptRoot 'results'
function Invoke-Region([string]$Name,[string[]]$Arguments) {
    $log=Join-Path $resultPath ($Name+'.log')
    & $GodotPath --path $projectPath --log-file $log @Arguments
    if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern '^(ERROR:|SCRIPT ERROR:|FAIL )' -Quiet)){throw "$Name failed"}
}
Invoke-Region 'stage6a2b_regions_import' @('--headless','--editor','--import')
foreach($script in @('scripts/apartment/floor5_visibility_policy.gd','scripts/apartment/floor5_region_builder.gd','scripts/apartment/floor5_region_presentation.gd','scripts/apartment/floor5_region_main.gd','tests/validate_stage6a2b_regions.gd','tests/capture_stage6a2b_regions.gd','tests/check_stage6a2b_region_images.gd')) {
    Invoke-Region ('stage6a2b_regions_parse_'+[IO.Path]::GetFileNameWithoutExtension($script)) @('--headless','--check-only','--script',('res://'+$script))
}
Invoke-Region 'stage6a2b_regions_smoke' @('--headless','--quit-after','120','res://scenes/apartment/stage6a2b_regions_floor5.tscn')
Invoke-Region 'stage6a2b_regions_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage6a2b_regions.gd')
$legacyError=$null
if($Regression) {
    try { & (Join-Path $PSScriptRoot 'run_stage6a2b_tests.ps1') -GodotPath $GodotPath -Regression }
    catch {$legacyError=$_.Exception.Message; Write-Output ('PRESERVED_OLD_GATE: '+$legacyError)}
}
if($Capture) {
    Invoke-Region 'stage6a2b_regions_render_validation' @('--fixed-fps','60','--script','res://tests/validate_stage6a2b_regions.gd')
    # Before screenshots were captured from the rejected B version before edits.
    # Preserve them. This captures only the corrected scene with matched settings.
    Invoke-Region 'stage6a2b_regions_capture' @('--script','res://tests/capture_stage6a2b_regions.gd','--','--after-only')
    Invoke-Region 'stage6a2b_regions_pixel_validation' @('--headless','--fixed-fps','60','--script','res://tests/check_stage6a2b_region_images.gd')
}
@{focused=(Get-Content (Join-Path $resultPath 'stage6a2b_regions_validation.json') -Raw|ConvertFrom-Json);capture_executed=[bool]$Capture;old_regressions_executed=[bool]$Regression;old_gate_error=$legacyError;human_acceptance='PENDING'}|ConvertTo-Json -Depth 12|Set-Content (Join-Path $resultPath 'stage6a2b_regions_run_summary.json') -Encoding utf8
if($legacyError){throw 'Regional checks finished; historical source-freeze failures remain. Inspect raw old results.'}
