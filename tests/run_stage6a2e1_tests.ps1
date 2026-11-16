param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture,[switch]$Regression)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resultPath=Join-Path $PSScriptRoot 'results'
function Invoke-E1([string]$Name,[string[]]$Arguments) {
    $log=Join-Path $resultPath ($Name+'.log')
    & $GodotPath --path $projectPath --log-file $log @Arguments
    if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern '^(ERROR:|SCRIPT ERROR:|FAIL )' -Quiet)){throw "$Name failed"}
}
Invoke-E1 'stage6a2e1_import' @('--headless','--editor','--import')
foreach($script in @('scripts/apartment/floor5_smooth_peek.gd','scripts/apartment/floor5_smooth_peek_main.gd','tests/inspect_stage6a2e1.gd','tests/validate_stage6a2e1.gd','tests/capture_stage6a2e1.gd','tests/render_stage6a2e1.gd')) {
    Invoke-E1 ('stage6a2e1_parse_'+[IO.Path]::GetFileNameWithoutExtension($script)) @('--headless','--check-only','--script',('res://'+$script))
}
Invoke-E1 'stage6a2e1_smoke' @('--headless','--quit-after','120','res://scenes/apartment/stage6a2e_floor5.tscn')
Invoke-E1 'stage6a2e1_before_scan' @('--headless','--fixed-fps','60','--script','res://tests/inspect_stage6a2e1.gd','--','--baseline')
Invoke-E1 'stage6a2e1_scan' @('--headless','--fixed-fps','60','--script','res://tests/inspect_stage6a2e1.gd')
Invoke-E1 'stage6a2e1_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage6a2e1.gd')
Copy-Item -LiteralPath (Join-Path $resultPath 'stage6a2e1_validation.json') -Destination (Join-Path $resultPath 'stage6a2e1_headless_validation.json')
if($Regression) {
    Invoke-E1 'stage6a2e1_e_regression' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage6a2e.gd')
    Invoke-E1 'stage6a2e1_c_regression' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage6a2c.gd')
    Invoke-E1 'stage6a2e1_d_regression' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage6a2d.gd')
}
if($Capture) {
    Invoke-E1 'stage6a2e1_render_logic' @('--fixed-fps','60','--script','res://tests/validate_stage6a2e1.gd')
    Copy-Item -LiteralPath (Join-Path $resultPath 'stage6a2e1_validation.json') -Destination (Join-Path $resultPath 'stage6a2e1_render_logic.json')
    Invoke-E1 'stage6a2e1_raster' @('--fixed-fps','60','--script','res://tests/render_stage6a2e1.gd')
    Invoke-E1 'stage6a2e1_capture' @('--fixed-fps','60','--script','res://tests/capture_stage6a2e1.gd')
}
