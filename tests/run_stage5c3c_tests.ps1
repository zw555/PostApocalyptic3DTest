param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resultPath=Join-Path $PSScriptRoot 'results'
$snapshot=Join-Path $resultPath 'stage5c3c_start_hashes.json'
if(-not(Test-Path -LiteralPath $snapshot)) {
    $entries=@(Get-ChildItem (Join-Path $projectPath 'scripts'),(Join-Path $projectPath 'scenes'),(Join-Path $projectPath 'materials'),(Join-Path $projectPath 'data'),(Join-Path $projectPath 'assets') -Recurse -File | Where-Object {$_.Extension -notin '.uid','.import'} | ForEach-Object {@{path=[IO.Path]::GetRelativePath($projectPath,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}})
    $entries | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $snapshot -Encoding utf8
}
& (Join-Path $PSScriptRoot 'run_stage5c3b_tests.ps1') -GodotPath $GodotPath -Capture:$Capture
$legacy=@('validate','validate_visual_upgrade','validate_camera_zoom','validate_cad_store','validate_store_loot','validate_scarcity_highlight','validate_art_localization','validate_camera_presets','validate_player_occlusion','validate_zombie_ai')
$runs=@()
foreach($name in $legacy) {
    $log=Join-Path $resultPath ('stage5c3c_legacy_'+$name+'.log')
    & $GodotPath --headless --path $projectPath --fixed-fps 60 --script ('res://tests/'+$name+'.gd') --log-file $log *> ($log+'.stdout')
    $runs+=@{test=$name;exit_code=$LASTEXITCODE;failures=@(Select-String -LiteralPath ($log+'.stdout') -Pattern '^(FAIL |ERROR:|SCRIPT ERROR:)' | ForEach-Object {$_.Line})}
}
$runs|ConvertTo-Json -Depth 6|Set-Content (Join-Path $resultPath 'stage5c3c_legacy_runs.json') -Encoding utf8
$arguments=@('--path',$projectPath,'--fixed-fps','60','--script','res://tests/validate_stage5c3c_integration.gd','--log-file',(Join-Path $resultPath 'stage5c3c_integration.log'))
if(-not $Capture){$arguments=@('--headless')+$arguments}
& $GodotPath @arguments
$integrationExit=$LASTEXITCODE
$integration=Get-Content (Join-Path $resultPath 'stage5c3c_integration.json') -Raw|ConvertFrom-Json
$failedRuns=@($runs|Where-Object {$_.exit_code -ne 0})
@{integration_passed=$integration.passed;integration_failed=$integration.failed;integration_exit=$integrationExit;legacy_failed_suites=$failedRuns.Count;legacy=$runs;all_original_checks_pass=($failedRuns.Count -eq 0 -and $integrationExit -eq 0);manual_final_acceptance='PENDING'}|ConvertTo-Json -Depth 7|Set-Content (Join-Path $resultPath 'stage5c3c_run_summary.json') -Encoding utf8
if($integrationExit -ne 0){throw 'Native integration failed'}
if($failedRuns.Count -gt 0){throw 'Legacy suites retain raw failures; see stage5c3c_legacy_runs.json. Historical SHA assertions were not waived or edited.'}
Write-Output 'PASS C.3-C automatic checks. Human final acceptance PENDING.'
