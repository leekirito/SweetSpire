param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [ValidateRange(2, 8)][int]$Players = 8,
    [switch]$Regular,
    [switch]$Private
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$enginePath = (Resolve-Path $GodotPath).Path
$logRoot = Join-Path $projectRoot '.godot/lan-tests'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$children = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()

function Start-TestProcess([string]$Scene, [string]$Label, [string[]]$UserArgs = @()) {
    $arguments = @('--headless', '--max-fps', '60', '--path', ('"' + $projectRoot + '"'),
        '--log-file', ('"' + (Join-Path $logRoot ($Label + '.log')) + '"'), $Scene)
    if ($UserArgs.Count -gt 0) { $arguments += '--'; $arguments += $UserArgs }
    $child = Start-Process -FilePath $enginePath -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $children.Add($child)
    return $child
}

function Wait-TestProcess([System.Diagnostics.Process]$Child, [string]$Label) {
    if (-not $Child.WaitForExit(150000)) { throw "$Label timed out; see $logRoot" }
    if ($Child.ExitCode -ne 0) { throw "$Label failed; see $logRoot" }
    Write-Output "$Label passed"
}

try {
    foreach ($suite in @('LanLobbyTest', 'LanUITest', 'LanRulesTest')) {
        $child = Start-TestProcess "res://scenes/network/tests/$suite.tscn" $suite
        Wait-TestProcess $child $suite
    }
    $peers = @()
    $modeArgs = @("--test-run=$([guid]::NewGuid().ToString('N'))")
    if ($Regular) { $modeArgs += '--regular' }
    if ($Private) { $modeArgs += '--private' }
    $peers += Start-TestProcess 'res://scenes/network/tests/LanProcessTest.tscn' 'host' (@('--host', "--players=$Players") + $modeArgs)
    Start-Sleep -Seconds 2
    for ($seat = 2; $seat -le $Players; $seat++) {
        $peers += Start-TestProcess 'res://scenes/network/tests/LanProcessTest.tscn' "guest-$seat" (@("--players=$Players") + $modeArgs)
        Start-Sleep -Milliseconds 500
    }
    for ($index = 0; $index -lt $peers.Count; $index++) {
        Wait-TestProcess $peers[$index] "LAN process $($index + 1)"
    }
    foreach ($suite in @('hotseat', 'selection', 'fog', 'structure', 'caster', 'map_generation')) {
        $child = Start-TestProcess "res://scenes/${suite}_regression_test.tscn" $suite
        Wait-TestProcess $child $suite
    }
    Write-Output "All LAN and local-mode tests passed. Logs: $logRoot"
}
finally {
    # Only stop processes created by this runner, leaving the user's editor alone.
    foreach ($child in $children) {
        if (-not $child.HasExited) { Stop-Process -Id $child.Id }
    }
}
