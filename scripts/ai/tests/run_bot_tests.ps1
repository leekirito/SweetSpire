param([Parameter(Mandatory=$true)][string]$GodotPath)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$logRoot = Join-Path $projectRoot '.godot/lan-tests'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$children = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()
function Launch([string]$scene, [string]$label, [string[]]$extra = @()) {
    $arguments = @('--headless', '--max-fps', '60', '--path', ('"' + $projectRoot + '"'), '--log-file', ('"' + (Join-Path $logRoot ($label + '.log')) + '"'), $scene)
    if ($extra.Count) { $arguments += '--'; $arguments += $extra }
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $children.Add($process)
    return $process
}
function Finish([System.Diagnostics.Process]$process, [string]$label) {
    if (-not $process.WaitForExit(120000)) { throw "$label timed out" }
    if ($process.ExitCode -ne 0) { throw "$label failed; see $logRoot" }
    $log = Get-Content (Join-Path $logRoot ($label + '.log')) -Raw
    if ($log -match 'SCRIPT ERROR:|BOT LAN:|Assertion failed') { throw "$label had script errors; see $logRoot" }
    Write-Output "$label passed"
}
try {
    $rules = Launch 'res://scenes/ai/tests/BotRulesTest.tscn' 'bot-rules'
    Finish $rules 'bot-rules'
    $ui = Launch 'res://scenes/network/tests/LanUITest.tscn' 'bot-ui'
    Finish $ui 'bot-ui'
    foreach ($mode in @('fog', 'regular')) {
        $extra = @("--test-run=$([guid]::NewGuid().ToString('N'))")
        if ($mode -eq 'regular') { $extra += '--regular' }
        $eight = Launch 'res://scenes/ai/tests/BotEightSeatsTest.tscn' "bot-eight-$mode" $extra
        Finish $eight "bot-eight-$mode"
        $solo = Launch 'res://scenes/ai/tests/BotLanTest.tscn' "bot-solo-$mode" ($extra + @('--host', '--solo'))
        Finish $solo "bot-solo-$mode"
        $hostProcess = Launch 'res://scenes/ai/tests/BotLanTest.tscn' "bot-host-$mode" ($extra + @('--host'))
        Start-Sleep -Seconds 2
        $guest = Launch 'res://scenes/ai/tests/BotLanTest.tscn' "bot-guest-$mode" $extra
        Finish $hostProcess "bot-host-$mode"
        Finish $guest "bot-guest-$mode"
    }
    $local = Launch 'res://scenes/ai/tests/BotRegressionTest.tscn' 'bot-regression'
    Finish $local 'bot-regression'
} finally {
    foreach ($process in $children) {
        if (-not $process.HasExited) { Stop-Process -Id $process.Id }
    }
}
