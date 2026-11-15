param(
    [string]$GodotPath = 'E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',
    [switch]$Capture
)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resultsPath = Join-Path $PSScriptRoot 'results'
& (Join-Path $PSScriptRoot 'run_tests.ps1') -GodotPath $GodotPath
if ($LASTEXITCODE -ne 0) { throw 'Existing project regression failed.' }
function Invoke-Cad([string]$Name, [string[]]$EngineArguments) {
    $logPath = Join-Path $resultsPath ($Name+'.log')
    & $GodotPath --path $projectPath --log-file $logPath @EngineArguments
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $logPath -Pattern '^(ERROR:|SCRIPT ERROR:)' -Quiet)) { throw "$Name failed; read $logPath" }
}
Invoke-Cad 'cad_scene_smoke' @('--headless','--quit-after','60','res://scenes/cad_convenience_store.tscn')
Invoke-Cad 'cad_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_cad_store.gd')
if ($Capture) {
    Invoke-Cad 'cad_capture' @('--script','res://tests/cad_capture.gd')
    Invoke-Cad 'cad_render_validation' @('--headless','--script','res://tests/verify_cad_render.gd')
}
Write-Output 'PASS: original regression + CAD layout/physics. Human playtest remains pending.'
