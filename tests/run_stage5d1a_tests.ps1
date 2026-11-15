param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resultPath=Join-Path $PSScriptRoot 'results'
New-Item -ItemType Directory -Path $resultPath -Force | Out-Null
$snapshot=Join-Path $resultPath 'stage5d1a_start_hashes.json'
if(-not(Test-Path -LiteralPath $snapshot)) {
    $entries=@(Get-ChildItem (Join-Path $projectPath 'scripts'),(Join-Path $projectPath 'scenes'),(Join-Path $projectPath 'materials'),(Join-Path $projectPath 'data'),(Join-Path $projectPath 'assets') -Recurse -File | Where-Object {$_.Extension -notin '.uid','.import'} | ForEach-Object {@{path=[IO.Path]::GetRelativePath($projectPath,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}})
    $entries|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $snapshot -Encoding utf8
}
function Invoke-D1([string]$Name,[string[]]$Arguments) {
    $log=Join-Path $resultPath ($Name+'.log')
    & $GodotPath --path $projectPath --log-file $log @Arguments
    if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern '^(ERROR:|SCRIPT ERROR:|FAIL )' -Quiet)){throw "$Name failed"}
}
foreach($script in @('scripts/ai/zombie_controller.gd','scripts/combat/stage5d1a_combat_metrics.gd','scripts/combat/stage5d1a_experiment_main.gd','tests/validate_stage5d1a.gd')) {
    Invoke-D1 ('stage5d1a_parse_'+[IO.Path]::GetFileNameWithoutExtension($script)) @('--headless','--check-only','--script',('res://'+$script))
}
Invoke-D1 'stage5d1a_smoke' @('--headless','--quit-after','120','res://scenes/combat/stage5d1a_experiment.tscn')
Invoke-D1 'stage5d1a_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage5d1a.gd')
if($Capture){Invoke-D1 'stage5d1a_render' @('--fixed-fps','60','--script','res://tests/validate_stage5d1a.gd')}
Write-Output 'PASS D.1-A targeted checks. Running original regressions without modifying assertions or historical snapshots.'
$regressionError=$null
try { & (Join-Path $PSScriptRoot 'run_stage5c3c_tests.ps1') -GodotPath $GodotPath }
catch { $regressionError=$_.Exception.Message; Write-Output ('ORIGINAL_REGRESSION_FAILURE: '+$regressionError) }
$deathLog=Join-Path $resultPath 'stage5d1a_death_regression.log'
$deathSnapshot=Join-Path $resultPath 'zombie_death_fix_start_hashes.json'
if(-not(Test-Path -LiteralPath $deathSnapshot)){Copy-Item -LiteralPath $snapshot -Destination $deathSnapshot}
& $GodotPath --headless --path $projectPath --fixed-fps 60 --script res://tests/validate_zombie_death_pose.gd --log-file $deathLog
$deathExit=$LASTEXITCODE
@{focused=(Get-Content (Join-Path $resultPath 'stage5d1a_validation.json') -Raw|ConvertFrom-Json);original_regression_error=$regressionError;death_regression_exit=$deathExit;manual_acceptance='PENDING';note='Raw historical and authorized-source protection failures are preserved. Inspect individual FAIL records; this is not an all-green claim.'}|ConvertTo-Json -Depth 10|Set-Content (Join-Path $resultPath 'stage5d1a_run_summary.json') -Encoding utf8
if($null -ne $regressionError -or $deathExit -ne 0){throw 'Original regressions reported failures; see raw logs/summary. No baseline or assertion was changed.'}
