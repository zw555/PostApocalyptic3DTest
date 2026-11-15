param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resultPath=Join-Path $PSScriptRoot 'results'
New-Item -ItemType Directory -Path $resultPath -Force | Out-Null
$snapshot=Join-Path $resultPath 'pose_blend_start_hashes.json'
if(-not(Test-Path -LiteralPath $snapshot)) {
    $entries=@(Get-ChildItem (Join-Path $projectPath 'scripts'),(Join-Path $projectPath 'scenes'),(Join-Path $projectPath 'materials'),(Join-Path $projectPath 'data'),(Join-Path $projectPath 'assets') -Recurse -File | Where-Object {$_.Extension -notin '.uid','.import'} | ForEach-Object {@{path=[IO.Path]::GetRelativePath($projectPath,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}})
    $entries|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $snapshot -Encoding utf8
}
function Invoke-Pose([string]$Name,[string[]]$Arguments) {
    $log=Join-Path $resultPath ($Name+'.log')
    & $GodotPath --path $projectPath --log-file $log @Arguments
    if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern '^(ERROR:|SCRIPT ERROR:|FAIL )' -Quiet)){throw "$Name failed"}
}
foreach($script in @('scripts/combat/stage5c1_character_attack_visual.gd','scripts/combat/stage5c3b_player_feedback.gd','tests/validate_stage5d1b_pose_blend.gd')) {
    Invoke-Pose ('pose_blend_parse_'+[IO.Path]::GetFileNameWithoutExtension($script)) @('--headless','--check-only','--script',('res://'+$script))
}
Invoke-Pose 'pose_blend_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage5d1b_pose_blend.gd')
if($Capture){Invoke-Pose 'pose_blend_render' @('--fixed-fps','60','--script','res://tests/validate_stage5d1b_pose_blend.gd')}
$regressionError=$null
try { & (Join-Path $PSScriptRoot 'run_stage5d1b_tests.ps1') -GodotPath $GodotPath -Capture:$Capture }
catch { $regressionError=$_.Exception.Message; Write-Output ('RAW_REGRESSION_FAILURE: '+$regressionError) }
@{focused=(Get-Content (Join-Path $resultPath 'pose_blend_validation.json') -Raw|ConvertFrom-Json);regression_error=$regressionError;manual_acceptance='PENDING';note='Old assertions and hash baselines unchanged; inspect preserved protection failures separately.'}|ConvertTo-Json -Depth 12|Set-Content (Join-Path $resultPath 'pose_blend_run_summary.json') -Encoding utf8
if($null -ne $regressionError){throw 'Original regression gates reported failures; see raw logs and source-protection classifications.'}
