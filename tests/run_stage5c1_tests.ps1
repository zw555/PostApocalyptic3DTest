param([string]$GodotPath='E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe',[switch]$Capture)
$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
function Invoke-5C([string]$Name,[string[]]$Arguments) {
    $resultPath=Join-Path $PSScriptRoot 'results'
    New-Item -ItemType Directory -Force -Path $resultPath | Out-Null
    $logPath=Join-Path $resultPath ($Name+'.log')
    $stdout=Join-Path $resultPath ($Name+'.stdout.log')
    $stderr=Join-Path $resultPath ($Name+'.stderr.log')
    $allArguments=@('--path',$projectPath,'--log-file',$logPath)+$Arguments
    @{executable=$GodotPath;arguments=$allArguments;started=(Get-Date -Format o)} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $resultPath ($Name+'.command.json'))
    $process=Start-Process -FilePath $GodotPath -ArgumentList $allArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if(-not $process.WaitForExit(180000)) {
        $process.Kill()
        $process.WaitForExit()
        $exitCode=124
    } else { $exitCode=$process.ExitCode }
    $exitCode | Set-Content -LiteralPath (Join-Path $resultPath ($Name+'.exitcode.txt'))
    Get-Content -LiteralPath $stdout
    Get-Content -LiteralPath $stderr
    if ($exitCode -ne 0 -or (Select-String -LiteralPath $stdout,$stderr -Pattern '^(ERROR:|SCRIPT ERROR:)|CrashHandlerException|signal 11' -Quiet)) { throw "$Name failed with exit $exitCode; see $stdout and $stderr" }
}
Invoke-5C 'stage5c1_parse' @('--headless','--check-only','--script','res://tests/validate_stage5c1.gd')
Invoke-5C 'stage5c1_smoke' @('--headless','--quit-after','120','res://scenes/combat/stage5c1_melee_validation.tscn')
Invoke-5C 'stage5c1_validation' @('--headless','--fixed-fps','60','--script','res://tests/validate_stage5c1.gd')
if ($Capture) { Invoke-5C 'stage5c1_render' @('--fixed-fps','60','--script','res://tests/stage5c1_capture.gd') }
Write-Output 'PASS Stage 5-C.1 automated validation. Human acceptance A-D PENDING.'
