param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
& (Join-Path $PSScriptRoot 'run_stage5c3a_tests.ps1') -GodotPath $GodotPath
function Invoke-B([string]$Name,[string[]]$Arguments) {
    $log=Join-Path $PSScriptRoot ('results/'+$Name+'.log')
    & $GodotPath --path $projectPath --log-file $log @Arguments
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern '^(ERROR:|SCRIPT ERROR:)' -Quiet)) {throw "$Name failed"}
}
$scripts=@('scripts/combat/stage5c3b_player_feedback.gd','scripts/combat/stage5c3b_health_hud.gd','scripts/combat/stage5c3b_validation_main.gd','scripts/combat/stage5c1_character_attack_visual.gd','scripts/survivor_animator.gd','tests/validate_stage5c3b.gd','tests/stage5c3b_capture.gd')
foreach($script in $scripts){Invoke-B ('stage5c3b_parse_'+[IO.Path]::GetFileNameWithoutExtension($script)) @('--headless','--check-only','--script',('res://'+$script))}
Invoke-B 'stage5c3b_smoke' @('--headless','--quit-after','120','res://scenes/combat/stage5c3b_feedback_validation.tscn')
Invoke-B 'stage5c3b_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage5c3b.gd')
if($Capture){Invoke-B 'stage5c3b_render' @('--script','res://tests/stage5c3b_capture.gd')}
Write-Output 'PASS Stage 5-C.3-B automatic checks. Human acceptance PENDING.'
