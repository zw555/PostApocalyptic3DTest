param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture,[switch]$Regression)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resultPath=Join-Path $PSScriptRoot 'results'
New-Item -ItemType Directory -Path $resultPath -Force|Out-Null
$snapshot=Join-Path $resultPath 'stage6a2_start_hashes.json'
if(-not(Test-Path -LiteralPath $snapshot)) {
    Push-Location $projectPath
    try {
        $paths=@(git ls-files)+@(git ls-files --others --exclude-standard)
        @($paths|Where-Object {[IO.Path]::GetExtension($_) -notin '.png','.import','.uid'}|ForEach-Object {@{path=$_;sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash}})|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $snapshot -Encoding utf8
    } finally {Pop-Location}
}
function Invoke-Floor([string]$Name,[string[]]$Arguments) {
    $log=Join-Path $resultPath ($Name+'.log')
    & $GodotPath --path $projectPath --log-file $log @Arguments
    if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern '^(ERROR:|SCRIPT ERROR:|FAIL )' -Quiet)){throw "$Name failed"}
}
Invoke-Floor 'stage6a2_import' @('--headless','--editor','--import')
foreach($script in @('scripts/apartment/floor5_layout.gd','scripts/apartment/floor5_door.gd','scripts/apartment/floor5_builder.gd','scripts/apartment/floor5_visibility.gd','scripts/apartment/floor5_main.gd','tests/validate_stage6a2.gd','tests/capture_stage6a2.gd')) {
    Invoke-Floor ('stage6a2_parse_'+[IO.Path]::GetFileNameWithoutExtension($script)) @('--headless','--check-only','--script',('res://'+$script))
}
Invoke-Floor 'stage6a2_smoke' @('--headless','--quit-after','120','res://scenes/apartment/stage6a2_floor5.tscn')
Invoke-Floor 'stage6a2_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage6a2.gd')
foreach($version in @('','b','c')) {
    Invoke-Floor ('stage6a2_original_a'+$version) @('--headless','--fixed-fps','60','--script',('res://tests/validate_stage6a1'+$version+'.gd'))
}
if($Capture) {
    Invoke-Floor 'stage6a2_render_validation' @('--fixed-fps','60','--script','res://tests/validate_stage6a2.gd')
    Invoke-Floor 'stage6a2_capture' @('--fixed-fps','60','--script','res://tests/capture_stage6a2.gd')
}
$combatError=$null
$legacy=@()
if($Regression) {
    # Reuse old combat gates headlessly; don't overwrite accepted screenshots.
    try { & (Join-Path $PSScriptRoot 'run_stage5c3b_tests.ps1') -GodotPath $GodotPath }
    catch {$combatError=$_.Exception.Message}
    foreach($name in @('validate_stage5d1b','validate_stage5d1b_pose_blend')) {
        Invoke-Floor ('stage6a2_combat_'+$name) @('--headless','--fixed-fps','60','--script',('res://tests/'+$name+'.gd'))
    }
    foreach($name in @('validate_camera_zoom','validate_camera_presets','validate_player_occlusion')) {
        $log=Join-Path $resultPath ('stage6a2_legacy_'+$name+'.log')
        & $GodotPath --path $projectPath --headless --fixed-fps 60 --script ('res://tests/'+$name+'.gd') --log-file $log
        $legacy+=@{suite=$name;exit_code=$LASTEXITCODE;failures=@(Select-String -LiteralPath $log -Pattern '^(FAIL |ERROR:|SCRIPT ERROR:)'|ForEach-Object {$_.Line})}
    }
}
@{focused=(Get-Content (Join-Path $resultPath 'stage6a2_validation.json') -Raw|ConvertFrom-Json);capture_executed=[bool]$Capture;combat_regression_error=$combatError;legacy=$legacy;human_acceptance='PENDING';note='Old assertions untouched; retained historical SHA failures are not passes.'}|ConvertTo-Json -Depth 14|Set-Content (Join-Path $resultPath 'stage6a2_run_summary.json') -Encoding utf8
if($null -ne $combatError -or @($legacy|Where-Object {$_.exit_code -ne 0}).Count -gt 0){throw 'Floor checks finished; old regression gate retains failures. Inspect original raw results.'}
