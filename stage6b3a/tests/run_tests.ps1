param([switch]$Render,[string]$GodotBin='E:/Godot_v4.5.2-stable_win64.exe/Godot_v4.5.2-stable_win64_console.exe')
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$rows=@(
 @{name='new_headless';script='validate_combat.gd';result='combat_headless.json';expected=@()},
 @{name='live_headless';script='validate_live_input.gd';result='live_headless.json';expected=@()},
 @{name='c1';script='validate_stage5c1.gd';result='legacy/stage5c1_validation.json';expected=@()},
 @{name='c2';script='validate_stage5c2.gd';result='legacy/stage5c2_validation.json';expected=@()},
 @{name='c3a';script='validate_stage5c3a.gd';result='legacy/stage5c3a_validation.json';expected=@()},
 @{name='c3b';script='validate_stage5c3b.gd';result='legacy/stage5c3b_validation.json';expected=@()},
 @{name='d1b';script='validate_stage5d1b.gd';result='legacy/stage5d1b_validation.json';expected=@('D1A work assets AI config and scene layouts preserved')},
 @{name='camera';script='validate_camera_presets.gd';result='legacy/stage4d3_validation.json';expected=@('Existing gameplay/layout/models/materials/config immutable')},
 @{name='occlusion';script='validate_player_occlusion.gd';result='legacy/stage5a_validation.json';expected=@('Prior gameplay/layout/models/materials/resources preserved')},
 @{name='inventory';script='a24b/legacy_data.gd';result='a24b/legacy_data.json';expected=@()},
 @{name='equipment';script='a24b/legacy_equipment.gd';result='a24b/legacy_equipment.json';expected=@()},
 @{name='a24b_headless';script='a24b/validate_hold.gd';result='a24b/journey_ui_headless.json';expected=@()}
)
if($Render){
 $rows+=@{name='new_render';script='validate_combat.gd';result='combat_render.json';expected=@();render=$true}
 $rows+=@{name='live_render';script='validate_live_input.gd';result='live_render.json';expected=@();render=$true}
 $rows+=@{name='a24b_render';script='a24b/validate_hold.gd';result='a24b/journey_ui_render.json';expected=@();render=$true}
}
$summary=@()
foreach($row in $rows){
 $log=Join-Path $projectRoot ('stage6b3a/evidence/run_'+$row.name+'.log')
 $arguments=@('--path',$projectRoot,'--script',('res://stage6b3a/tests/'+$row.script),'--log-file',$log)
 if($row.render){$arguments+=@('--resolution','1440x1000')}else{$arguments+=@('--headless')}
 if($row.name -eq 'c2'){$arguments+=@('--','--stage5c2-output','res://stage6b3a/evidence/legacy/stage5c2_validation.json')}
 $started=Get-Date
 & $GodotBin @arguments
 $code=$LASTEXITCODE
 $output=Join-Path $projectRoot ('stage6b3a/evidence/'+$row.result)
 $unexpected=$true
 $data=$null
 if((Test-Path -LiteralPath $output) -and (Get-Item -LiteralPath $output).LastWriteTime -ge $started){
  $data=Get-Content -LiteralPath $output -Raw -Encoding UTF8 | ConvertFrom-Json
  $checks=if($null -ne $data.tests){$data.tests}else{$data.checks}
  $failures=@($checks | Where-Object passed -eq $false | ForEach-Object test)
  $sameFailures=(@($row.expected | Sort-Object) -join "`n") -ceq (@($failures | Sort-Object) -join "`n")
  $errors=@(Select-String -LiteralPath $log -Pattern '^(SCRIPT ERROR|ERROR):')
  $expectedCode=if($row.expected.Count -gt 0){1}else{0}
  $unexpected=($code -ne $expectedCode -or -not $sameFailures -or $errors.Count -gt 0)
 }
 $summary+=@{name=$row.name;exit_code=$code;passed=$data.passed;failed=$data.failed;expected_freeze_failures=$row.expected;unexpected=$unexpected;log=$log}
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $projectRoot 'stage6b3a/evidence/run_summary.json') -Encoding UTF8
if(@($summary | Where-Object unexpected -eq $true).Count -gt 0){throw 'Unexpected failure; inspect stage6b3a/evidence/run_summary.json'}
Write-Output 'Completed with explicitly recorded freeze failures; this is not an all-green result.'
