param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture,[switch]$Regression)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resultPath=Join-Path $PSScriptRoot 'results'
New-Item -ItemType Directory -Path $resultPath -Force|Out-Null
$snapshot=Join-Path $resultPath 'stage6a1b_start_hashes.json'
if(-not(Test-Path -LiteralPath $snapshot)) {
    # Snapshot current sources once. Preserve the original audit snapshot on reruns.
    Push-Location $projectPath
    try {
        $paths=@(git ls-files)+@(git ls-files --others --exclude-standard)
        @($paths|Where-Object {[IO.Path]::GetExtension($_) -notin '.png','.import','.uid'}|ForEach-Object {@{path=$_;sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash}})|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $snapshot -Encoding utf8
    } finally {Pop-Location}
}
function Invoke-Refinement([string]$Name,[string[]]$Arguments) {
    $log=Join-Path $resultPath ($Name+'.log')
    & $GodotPath --path $projectPath --log-file $log @Arguments
    if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern '^(ERROR:|SCRIPT ERROR:|FAIL )' -Quiet)){throw "$Name failed"}
}
Invoke-Refinement 'stage6a1b_import' @('--headless','--editor','--import')
foreach($script in @('scripts/apartment/apartment_refinement_builder.gd','scripts/apartment/apartment_refinement_main.gd','tests/validate_stage6a1b.gd','tests/capture_stage6a1b.gd')) {
    Invoke-Refinement ('stage6a1b_parse_'+[IO.Path]::GetFileNameWithoutExtension($script)) @('--headless','--check-only','--script',('res://'+$script))
}
Invoke-Refinement 'stage6a1b_smoke' @('--headless','--quit-after','120','res://scenes/apartment/stage6a1b_apartment.tscn')
Invoke-Refinement 'stage6a1b_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage6a1b.gd')
Invoke-Refinement 'stage6a1_regression' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage6a1.gd')
if($Capture) {
    Invoke-Refinement 'stage6a1b_render_validation' @('--fixed-fps','60','--script','res://tests/validate_stage6a1b.gd')
    # Sequential GPU passes at identical resolution, camera, zoom, position and
    # sampling protocol; keep each scene's intended lighting on.
    Invoke-Refinement 'stage6a1b_before_render' @('--script','res://tests/capture_stage6a1b.gd','--','--baseline')
    Invoke-Refinement 'stage6a1b_after_render' @('--script','res://tests/capture_stage6a1b.gd')
}
$regressionError=$null
if($Regression) {
    try { & (Join-Path $PSScriptRoot 'run_pose_blend_tests.ps1') -GodotPath $GodotPath }
    catch {$regressionError=$_.Exception.Message; Write-Output ('PRESERVED_OLD_GATE_FAILURE: '+$regressionError)}
}
@{focused=(Get-Content (Join-Path $resultPath 'stage6a1b_validation.json') -Raw|ConvertFrom-Json);original_apartment=(Get-Content (Join-Path $resultPath 'stage6a1_validation.json') -Raw|ConvertFrom-Json);capture_executed=[bool]$Capture;old_regressions_executed=[bool]$Regression;old_gate_error=$regressionError;human_acceptance='PENDING'}|ConvertTo-Json -Depth 12|Set-Content (Join-Path $resultPath 'stage6a1b_run_summary.json') -Encoding utf8
if($null -ne $regressionError){throw 'B checks complete; unchanged historical regression gates report failure. Inspect the original source-freeze assertions.'}
