param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture,[switch]$Regression)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resultPath=Join-Path $PSScriptRoot 'results'
New-Item -ItemType Directory -Path $resultPath -Force|Out-Null
$snapshot=Join-Path $resultPath 'stage6a2b_start_hashes.json'
if(-not(Test-Path -LiteralPath $snapshot)) {
    Push-Location $projectPath
    try {
        $paths=@(git ls-files)+@(git ls-files --others --exclude-standard)
        @($paths|Where-Object {[IO.Path]::GetExtension($_) -notin '.png','.import','.uid'}|ForEach-Object {@{path=$_;sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash}})|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $snapshot -Encoding utf8
    } finally {Pop-Location}
}
function Invoke-Policy([string]$Name,[string[]]$Arguments) {
    $log=Join-Path $resultPath ($Name+'.log')
    & $GodotPath --path $projectPath --log-file $log @Arguments
    if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern '^(ERROR:|SCRIPT ERROR:|FAIL )' -Quiet)){throw "$Name failed"}
}
Invoke-Policy 'stage6a2b_import' @('--headless','--editor','--import')
foreach($script in @('scripts/apartment/floor5_main.gd','scripts/apartment/floor5_regions.gd','scripts/apartment/floor5_visibility_builder.gd','scripts/apartment/floor5_visibility_policy.gd','scripts/apartment/floor5_visibility_main.gd','tests/validate_stage6a2b.gd','tests/capture_stage6a2b.gd')) {
    Invoke-Policy ('stage6a2b_parse_'+[IO.Path]::GetFileNameWithoutExtension($script)) @('--headless','--check-only','--script',('res://'+$script))
}
Invoke-Policy 'stage6a2b_smoke' @('--headless','--quit-after','120','res://scenes/apartment/stage6a2b_floor5.tscn')
Invoke-Policy 'stage6a2b_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage6a2b.gd')
$legacyError=$null
if($Regression) {
    # Original A2 scene and all original assertions remain intact. No old images.
    try { & (Join-Path $PSScriptRoot 'run_stage6a2_tests.ps1') -GodotPath $GodotPath -Regression }
    catch {$legacyError=$_.Exception.Message; Write-Output ('PRESERVED_OLD_GATE: '+$legacyError)}
}
if($Capture) {
    Invoke-Policy 'stage6a2b_render_validation' @('--fixed-fps','60','--script','res://tests/validate_stage6a2b.gd')
    # Sequential six-second sampled runs after headless regression has ended.
    Invoke-Policy 'stage6a2b_capture' @('--script','res://tests/capture_stage6a2b.gd')
}
@{focused=(Get-Content (Join-Path $resultPath 'stage6a2b_validation.json') -Raw|ConvertFrom-Json);capture_executed=[bool]$Capture;old_regressions_executed=[bool]$Regression;old_gate_error=$legacyError;human_acceptance='PENDING';note='Historical SHA failures preserved; no old assertions or snapshots updated.'}|ConvertTo-Json -Depth 14|Set-Content (Join-Path $resultPath 'stage6a2b_run_summary.json') -Encoding utf8
if($null -ne $legacyError){throw 'Policy checks completed; original regression gate retains failures. Inspect raw old results.'}
