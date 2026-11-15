param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe')
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
function Invoke-Core([string]$Name,[string[]]$Arguments) {
    $log=Join-Path $PSScriptRoot ('results/'+$Name+'.log')
    & $GodotPath --path $projectPath --log-file $log @Arguments
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern '^(ERROR:|SCRIPT ERROR:)' -Quiet)) {throw "$Name failed"}
}
$scripts=@('scripts/combat/stage5c3_player_combat_component.gd','scripts/combat/stage5c3_zombie_melee_controller.gd','scripts/combat/stage5c3a_validation_main.gd','scripts/player_controller.gd','scripts/combat/stage5c1_melee_attack_controller.gd','scripts/combat/stage5c1_aim_controller.gd','scripts/ai/zombie_controller.gd','tests/validate_stage5c3a.gd')
foreach($script in $scripts){Invoke-Core ('stage5c3a_parse_'+[IO.Path]::GetFileNameWithoutExtension($script)) @('--headless','--check-only','--script',('res://'+$script))}
Invoke-Core 'stage5c3a_smoke' @('--headless','--quit-after','120','res://scenes/combat/stage5c3a_dual_combat_validation.tscn')
Invoke-Core 'stage5c3a_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage5c3a.gd')
& (Join-Path $PSScriptRoot 'run_stage5c1_tests.ps1') -GodotPath $GodotPath
& (Join-Path $PSScriptRoot 'run_stage5c2_tests.ps1') -GodotPath $GodotPath
Write-Output 'PASS C.3-A core and C.1/C.2 regressions. Human acceptance PENDING.'
