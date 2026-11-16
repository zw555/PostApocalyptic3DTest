param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture,[switch]$Regression)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resultPath=Join-Path $PSScriptRoot 'results'
function Invoke-E([string]$Name,[string[]]$Arguments) {
    $log=Join-Path $resultPath ($Name+'.log')
    & $GodotPath --path $projectPath --log-file $log @Arguments
    if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern '^(ERROR:|SCRIPT ERROR:|FAIL )' -Quiet)){throw "$Name failed"}
}
Invoke-E 'stage6a2e_import' @('--headless','--editor','--import')
foreach($script in @('scripts/apartment/floor5_smooth_peek.gd','scripts/apartment/floor5_smooth_peek_main.gd','tests/validate_stage6a2e.gd','tests/capture_stage6a2e.gd','tests/render_stage6a2e.gd')) {
    Invoke-E ('stage6a2e_parse_'+[IO.Path]::GetFileNameWithoutExtension($script)) @('--headless','--check-only','--script',('res://'+$script))
}
Invoke-E 'stage6a2e_smoke' @('--headless','--quit-after','120','res://scenes/apartment/stage6a2e_floor5.tscn')
Invoke-E 'stage6a2e_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage6a2e.gd')
Copy-Item -LiteralPath (Join-Path $resultPath 'stage6a2e_validation.json') -Destination (Join-Path $resultPath 'stage6a2e_headless_validation.json')
if($Regression) {
    Invoke-E 'stage6a2e_c_regression' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage6a2c.gd')
    Invoke-E 'stage6a2e_d_regression' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage6a2d.gd')
}
if($Capture) {
    Invoke-E 'stage6a2e_render_logic' @('--fixed-fps','60','--script','res://tests/validate_stage6a2e.gd')
    Copy-Item -LiteralPath (Join-Path $resultPath 'stage6a2e_validation.json') -Destination (Join-Path $resultPath 'stage6a2e_render_logic.json')
    Invoke-E 'stage6a2e_raster' @('--fixed-fps','60','--script','res://tests/render_stage6a2e.gd')
    Invoke-E 'stage6a2e_capture' @('--script','res://tests/capture_stage6a2e.gd')
}
