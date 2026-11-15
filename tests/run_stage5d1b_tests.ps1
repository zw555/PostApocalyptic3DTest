param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resultPath=Join-Path $PSScriptRoot 'results'
New-Item -ItemType Directory -Path $resultPath -Force | Out-Null
$snapshot=Join-Path $resultPath 'stage5d1b_start_hashes.json'
if(-not(Test-Path -LiteralPath $snapshot)) {
    $entries=@(Get-ChildItem (Join-Path $projectPath 'scripts'),(Join-Path $projectPath 'scenes'),(Join-Path $projectPath 'materials'),(Join-Path $projectPath 'data'),(Join-Path $projectPath 'assets') -Recurse -File | Where-Object {$_.Extension -notin '.uid','.import'} | ForEach-Object {@{path=[IO.Path]::GetRelativePath($projectPath,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}})
    $entries|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $snapshot -Encoding utf8
}
# Initialize only missing local run snapshots; never rewrite existing baselines.
foreach($name in @('stage5d1a_start_hashes.json','stage5c3c_start_hashes.json','zombie_death_fix_start_hashes.json')) {
    $path=Join-Path $resultPath $name
    if(-not(Test-Path -LiteralPath $path)){Copy-Item -LiteralPath $snapshot -Destination $path}
}
function Invoke-Ready([string]$Name,[string[]]$Arguments) {
    $log=Join-Path $resultPath ($Name+'.log')
    & $GodotPath --path $projectPath --log-file $log @Arguments
    if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern '^(ERROR:|SCRIPT ERROR:|FAIL )' -Quiet)){throw "$Name failed"}
}
foreach($script in @('scripts/combat/stage5c1_melee_attack_controller.gd','scripts/combat/stage5c1_character_attack_visual.gd','scripts/combat/stage5c3b_player_feedback.gd','scripts/player_controller.gd','scripts/combat/stage5d1b_validation_main.gd','tests/validate_stage5d1b.gd')) {
    Invoke-Ready ('stage5d1b_parse_'+[IO.Path]::GetFileNameWithoutExtension($script)) @('--headless','--check-only','--script',('res://'+$script))
}
Invoke-Ready 'stage5d1b_smoke' @('--headless','--quit-after','120','res://scenes/combat/stage5d1b_ready_stance.tscn')
Invoke-Ready 'stage5d1b_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage5d1b.gd')
if($Capture){Invoke-Ready 'stage5d1b_render' @('--fixed-fps','60','--script','res://tests/validate_stage5d1b.gd')}
$regressionError=$null
try { & (Join-Path $PSScriptRoot 'run_stage5c3c_tests.ps1') -GodotPath $GodotPath }
catch { $regressionError=$_.Exception.Message; Write-Output ('ORIGINAL_REGRESSION_FAILURE: '+$regressionError) }
$runs=@()
foreach($entry in @(@{name='stage5d1a';script='validate_stage5d1a.gd'},@{name='death_pose';script='validate_zombie_death_pose.gd'})) {
    $log=Join-Path $resultPath ('stage5d1b_regression_'+$entry.name+'.log')
    & $GodotPath --headless --path $projectPath --fixed-fps 60 --script ('res://tests/'+$entry.script) --log-file $log
    $runs+=@{name=$entry.name;exit_code=$LASTEXITCODE;failures=@(Select-String -LiteralPath $log -Pattern '^(FAIL |ERROR:|SCRIPT ERROR:)'|ForEach-Object {$_.Line})}
}
@{ready=(Get-Content (Join-Path $resultPath 'stage5d1b_validation.json') -Raw|ConvertFrom-Json);original_regression_error=$regressionError;regressions=$runs;manual_acceptance='PENDING';note='Original assertions and historical source snapshots were preserved. See exact protection-vs-behavior failures; no all-green claim.'}|ConvertTo-Json -Depth 12|Set-Content (Join-Path $resultPath 'stage5d1b_run_summary.json') -Encoding utf8
if($null -ne $regressionError -or @($runs|Where-Object {$_.exit_code -ne 0}).Count -gt 0){throw 'Original regression gates reported failures. Inspect source-protection and functional results separately.'}
