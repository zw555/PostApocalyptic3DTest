param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$snapshot=Join-Path $PSScriptRoot 'results/zombie_death_fix_start_hashes.json'
if(-not(Test-Path -LiteralPath $snapshot)) {
    $entries=@(Get-ChildItem (Join-Path $projectPath 'scripts'),(Join-Path $projectPath 'scenes'),(Join-Path $projectPath 'materials'),(Join-Path $projectPath 'data'),(Join-Path $projectPath 'assets') -Recurse -File | Where-Object {$_.Extension -notin '.uid','.import'} | ForEach-Object {@{path=[IO.Path]::GetRelativePath($projectPath,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}})
    $entries|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $snapshot -Encoding utf8
}
$integrationSnapshot=Join-Path $PSScriptRoot 'results/stage5c3c_start_hashes.json'
if(-not(Test-Path -LiteralPath $integrationSnapshot)) {
    Copy-Item -LiteralPath $snapshot -Destination $integrationSnapshot
}
& (Join-Path $PSScriptRoot 'run_stage5c3b_tests.ps1') -GodotPath $GodotPath -Capture:$Capture
function Invoke-DeathCheck([string]$Name,[string[]]$Arguments) {
    $log=Join-Path $PSScriptRoot ('results/'+$Name+'.log')
    & $GodotPath --path $projectPath --log-file $log @Arguments
    if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern '^(ERROR:|SCRIPT ERROR:|FAIL )' -Quiet)){throw "$Name failed"}
}
foreach($script in @('scripts/ai/zombie_visual.gd','tests/validate_zombie_death_pose.gd','tests/validate_stage5c3c_integration.gd')) {
    Invoke-DeathCheck ('death_fix_parse_'+[IO.Path]::GetFileNameWithoutExtension($script)) @('--headless','--check-only','--script',('res://'+$script))
}
Invoke-DeathCheck 'zombie_death_fix_c3c' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage5c3c_integration.gd')
Invoke-DeathCheck 'zombie_death_pose_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_zombie_death_pose.gd')
if($Capture){Invoke-DeathCheck 'zombie_death_pose_render' @('--fixed-fps','60','--script','res://tests/validate_zombie_death_pose.gd')}
Write-Output 'PASS focused corpse animation regression and C.1/C.2/C.3-A/B/C integration. Human corpse-pose acceptance PENDING. Historical SHA baseline policy unchanged.'
