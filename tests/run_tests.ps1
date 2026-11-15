param(
    [string]$GodotPath = 'E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',
    [switch]$Capture,
    [switch]$VisualCapture
)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not (Test-Path -LiteralPath $GodotPath)) {
    $installedGodot = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $installedGodot) { throw 'Godot not found. Pass -GodotPath to the installed 4.5.2 executable.' }
    $GodotPath = $installedGodot.Source
}
$resultPath = Join-Path $PSScriptRoot 'results'
New-Item -ItemType Directory -Path $resultPath -Force | Out-Null
$engineVersion = (& $GodotPath --headless --version | Out-String).Trim()
if ($engineVersion -notmatch '^4\.5\.2\.') { throw "Expected Godot 4.5.2, found $engineVersion" }

function Invoke-GodotCheck([string]$Name, [string[]]$EngineArguments) {
    $log = Join-Path $resultPath ($Name + '.log')
    & $GodotPath --path $projectPath --log-file $log @EngineArguments
    if ($LASTEXITCODE -ne 0) { throw "$Name failed with exit code $LASTEXITCODE" }
    if (Select-String -LiteralPath $log -Pattern '^(SCRIPT ERROR:|ERROR:)' -Quiet) { throw "$Name reported errors. Read $log" }
}

Invoke-GodotCheck 'import' @('--headless', '--editor', '--import')
$scriptFiles = Get-ChildItem -LiteralPath (Join-Path $projectPath 'scripts'), $PSScriptRoot -Recurse -Filter '*.gd'
foreach ($scriptFile in $scriptFiles) {
    $scriptResource = 'res://' + $scriptFile.FullName.Substring($projectPath.Length + 1).Replace('\', '/')
    Invoke-GodotCheck ('parse_' + $scriptFile.BaseName) @('--headless', '--check-only', '--script', $scriptResource)
}
Invoke-GodotCheck 'main_smoke' @('--headless', '--quit-after', '30')
Invoke-GodotCheck 'validation' @('--headless', '--fixed-fps', '60', '--script', 'res://tests/validate.gd')
Invoke-GodotCheck 'visual_upgrade_validation' @('--headless', '--script', 'res://tests/validate_visual_upgrade.gd')
Invoke-GodotCheck 'camera_zoom_validation' @('--headless', '--script', 'res://tests/validate_camera_zoom.gd')
if ($Capture) {
    Invoke-GodotCheck 'capture' @('--script', 'res://tests/capture.gd')
    Invoke-GodotCheck 'render_validation' @('--headless', '--script', 'res://tests/verify_captures.gd')
}
if ($VisualCapture) {
    Invoke-GodotCheck 'round2_final_capture' @('--script', 'res://tests/visual_capture.gd', '--', 'stage=final', 'frames=600')
    Invoke-GodotCheck 'round2_comparison_validation' @('--headless', '--script', 'res://tests/verify_visual_comparison.gd')
}
$summary = Get-Content -LiteralPath (Join-Path $resultPath 'validation.json') -Raw | ConvertFrom-Json
$visualSummary = Get-Content -LiteralPath (Join-Path $resultPath 'visual_upgrade_validation.json') -Raw | ConvertFrom-Json
$zoomSummary = Get-Content -LiteralPath (Join-Path $resultPath 'camera_zoom_validation.json') -Raw | ConvertFrom-Json
[ordered]@{ engine = $engineVersion; import = 'PASS'; parsed_scripts = $scriptFiles.Count; main_scene = 'PASS'; checks_passed = $summary.passed; checks_failed = $summary.failed; visual_checks_passed = $visualSummary.passed; visual_checks_failed = $visualSummary.failed; zoom_checks_passed = $zoomSummary.passed; zoom_checks_failed = $zoomSummary.failed; captures_requested = [bool]($Capture -or $VisualCapture) } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $resultPath 'test_run_summary.json') -Encoding UTF8
Write-Output "PASS: import, $($scriptFiles.Count) script parses, main load, $($summary.passed) regression + $($visualSummary.passed) visual + $($zoomSummary.passed) zoom checks."
