param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture,[switch]$Regression)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resultPath=Join-Path $PSScriptRoot 'results'
New-Item -ItemType Directory -Path $resultPath -Force|Out-Null
$snapshot=Join-Path $resultPath 'stage6a1c_start_hashes.json'
if(-not(Test-Path -LiteralPath $snapshot)) {
    Push-Location $projectPath
    try {
        $paths=@(git ls-files)+@(git ls-files --others --exclude-standard)
        @($paths|Where-Object {[IO.Path]::GetExtension($_) -notin '.png','.import','.uid'}|ForEach-Object {@{path=$_;sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash}})|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $snapshot -Encoding utf8
    } finally {Pop-Location}
}
function Invoke-Orientation([string]$Name,[string[]]$Arguments) {
    $log=Join-Path $resultPath ($Name+'.log')
    & $GodotPath --path $projectPath --log-file $log @Arguments
    if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern '^(ERROR:|SCRIPT ERROR:|FAIL )' -Quiet)){throw "$Name failed"}
}
Invoke-Orientation 'stage6a1c_import' @('--headless','--editor','--import')
foreach($script in @('scripts/apartment/apartment_orientation_builder.gd','scripts/apartment/apartment_orientation_main.gd','scripts/apartment/apartment_bathroom_visibility.gd','tests/validate_stage6a1c.gd','tests/capture_stage6a1c.gd')) {
    Invoke-Orientation ('stage6a1c_parse_'+[IO.Path]::GetFileNameWithoutExtension($script)) @('--headless','--check-only','--script',('res://'+$script))
}
Invoke-Orientation 'stage6a1c_smoke' @('--headless','--quit-after','120','res://scenes/apartment/stage6a1c_apartment.tscn')
Invoke-Orientation 'stage6a1c_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage6a1c.gd')
Invoke-Orientation 'stage6a1c_original_a_regression' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage6a1.gd')
Invoke-Orientation 'stage6a1c_original_b_regression' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage6a1b.gd')
if($Capture) {
    Invoke-Orientation 'stage6a1c_render_validation' @('--fixed-fps','60','--script','res://tests/validate_stage6a1c.gd')
    Invoke-Orientation 'stage6a1c_capture' @('--fixed-fps','60','--script','res://tests/capture_stage6a1c.gd')
}
$legacy=@()
if($Regression) {
    foreach($name in @('validate_camera_zoom','validate_camera_presets','validate_player_occlusion')) {
        $log=Join-Path $resultPath ('stage6a1c_legacy_'+$name+'.log')
        & $GodotPath --path $projectPath --headless --fixed-fps 60 --script ('res://tests/'+$name+'.gd') --log-file $log
        $legacy+=@{suite=$name;exit_code=$LASTEXITCODE;failures=@(Select-String -LiteralPath $log -Pattern '^(FAIL |ERROR:|SCRIPT ERROR:)'|ForEach-Object {$_.Line})}
    }
}
@{focused=(Get-Content (Join-Path $resultPath 'stage6a1c_validation.json') -Raw|ConvertFrom-Json);capture_executed=[bool]$Capture;legacy=$legacy;human_acceptance='PENDING';note='Old assertions and original A/B sources unchanged. Old SHA failures are not waived.'}|ConvertTo-Json -Depth 14|Set-Content (Join-Path $resultPath 'stage6a1c_run_summary.json') -Encoding utf8
if(@($legacy|Where-Object {$_.exit_code -ne 0}).Count -gt 0){throw 'C checks passed; historical source-freeze regression gates retain raw failures. See summary.'}
