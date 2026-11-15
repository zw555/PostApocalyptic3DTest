param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$runStamp=(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8)
$resultPath=Join-Path $PSScriptRoot ('results\stage5c2_runs\'+$runStamp)
New-Item -ItemType Directory -Force -Path $resultPath | Out-Null
$userData=Join-Path $resultPath 'user-data'
New-Item -ItemType Directory -Force -Path (Join-Path $userData 'logs') | Out-Null
$validationJson=Join-Path $resultPath 'stage5c2_validation.json'
function Invoke-5C2([string]$Name,[string[]]$Arguments) {
    $logPath=Join-Path $resultPath ($Name+'.log')
    $stdout=Join-Path $resultPath ($Name+'.stdout.log')
    $stderr=Join-Path $resultPath ($Name+'.stderr.log')
    $allArguments=@('--path',$projectPath,'--user-data-dir',$userData,'--log-file',$logPath)+$Arguments
    @{executable=$GodotPath;arguments=$allArguments;started=(Get-Date -Format o)} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $resultPath ($Name+'.command.json'))
    $process=Start-Process -FilePath $GodotPath -ArgumentList $allArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if(-not $process.WaitForExit(180000)) { $process.Kill(); $process.WaitForExit(); $exitCode=124 } else { $process.Refresh(); $exitCode=[int]$process.ExitCode }
    $exitCode | Set-Content -LiteralPath (Join-Path $resultPath ($Name+'.exitcode.txt'))
    Get-Content -LiteralPath $stdout
    Get-Content -LiteralPath $stderr
    if ($exitCode -ne 0 -or (Select-String -LiteralPath $stdout,$stderr -Pattern '^(ERROR:|SCRIPT ERROR:)|CrashHandlerException|signal 11' -Quiet)) { throw "$Name failed with exit $exitCode; see $stdout and $stderr" }
}
Invoke-5C2 'stage5c2_parse' @('--headless','--check-only','--script','res://tests/validate_stage5c2.gd')
Invoke-5C2 'stage5c2_smoke' @('--headless','--quit-after','120','res://scenes/combat/stage5c2_melee_validation.tscn')
Invoke-5C2 'stage5c2_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage5c2.gd','--','--stage5c2-output',$validationJson)
$validation=Get-Content -LiteralPath $validationJson -Raw | ConvertFrom-Json
if ($validation.failed -ne 0 -or $validation.passed -ne 22 -or @($validation.tests).Count -ne 22) {
    throw "Unexpected Stage 5-C.2 validation result; see $validationJson"
}
Write-Output 'Stage 5-C.2 automated checks completed. Human acceptance remains pending.'
Write-Output "Results: $resultPath"
