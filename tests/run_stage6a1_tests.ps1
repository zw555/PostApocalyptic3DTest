param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture,[switch]$Regression)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resultPath=Join-Path $PSScriptRoot 'results'
New-Item -ItemType Directory -Path $resultPath -Force|Out-Null
$snapshot=Join-Path $resultPath 'stage6a1_existing_hashes.json'
if(-not(Test-Path -LiteralPath $snapshot)) {
    Push-Location $projectPath
    try {
        $paths=@(git ls-files)
        $entries=@($paths|Where-Object {[IO.Path]::GetExtension($_) -notin '.png','.import','.uid'}|ForEach-Object {@{path=$_;sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash}})
        $entries|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $snapshot -Encoding utf8
    } finally {Pop-Location}
}
function Invoke-Apartment([string]$Name,[string[]]$Arguments) {
    $log=Join-Path $resultPath ($Name+'.log')
    & $GodotPath --path $projectPath --log-file $log @Arguments
    if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern '^(ERROR:|SCRIPT ERROR:|FAIL )' -Quiet)){throw "$Name failed"}
}
foreach($script in @('scripts/apartment/apartment_layout.gd','scripts/apartment/apartment_builder.gd','scripts/apartment/apartment_camera.gd','scripts/apartment/apartment_occluders.gd','scripts/apartment/apartment_main.gd','tests/validate_stage6a1.gd','tests/capture_stage6a1.gd')) {
    Invoke-Apartment ('stage6a1_parse_'+[IO.Path]::GetFileNameWithoutExtension($script)) @('--headless','--check-only','--script',('res://'+$script))
}
Invoke-Apartment 'stage6a1_smoke' @('--headless','--quit-after','120','res://scenes/apartment/stage6a1_apartment.tscn')
Invoke-Apartment 'stage6a1_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage6a1.gd')
if($Capture){Invoke-Apartment 'stage6a1_render' @('--fixed-fps','60','--script','res://tests/capture_stage6a1.gd')}
$regressionError=$null
if($Regression) {
    # Headless old regressions: never overwrite their committed screenshots.
    try { & (Join-Path $PSScriptRoot 'run_pose_blend_tests.ps1') -GodotPath $GodotPath }
    catch { $regressionError=$_.Exception.Message; Write-Output ('PRESERVED_OLD_GATE_FAILURE: '+$regressionError) }
}
@{apartment=(Get-Content (Join-Path $resultPath 'stage6a1_validation.json') -Raw|ConvertFrom-Json);capture_executed=[bool]$Capture;old_regressions_executed=[bool]$Regression;old_gate_error=$regressionError;manual_acceptance='PENDING';note='Apartment must not be marked manually complete before player acceptance. Old frozen-source assertions are unchanged.'}|ConvertTo-Json -Depth 12|Set-Content (Join-Path $resultPath 'stage6a1_run_summary.json') -Encoding utf8
if($null -ne $regressionError){throw 'Apartment checks passed; original regression gate reports failure. Inspect preserved source-freeze results separately.'}
