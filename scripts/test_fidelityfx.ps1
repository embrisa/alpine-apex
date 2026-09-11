# Run through run_guarded.ps1 to hold the shared validation lock for this batch.
param()
$ErrorActionPreference = 'Stop'
$fsrRoot = Split-Path $PSScriptRoot -Parent
$fsrExe = Join-Path $fsrRoot '.tools/godot-fsr/bin/godot.windows.template_debug.x86_64.console.exe'
& (Join-Path $PSScriptRoot 'build_fidelityfx_probe.ps1') -Run *> (Join-Path $fsrRoot 'artifacts/fidelityfx/probe-build.log')
$fsrResults = @()
$fsrCases = @(
    @{name='gpu_validation';args=@('--rendering-driver','d3d12','--gpu-validation','--disable-crash-handler','--script','tests/fidelityfx_playtest.gd')},
    @{name='game';args=@('--rendering-driver','d3d12','--gpu-validation','--disable-crash-handler','--script','tests/fidelityfx_game_playtest.gd')},
    @{name='settings';args=@('--headless','--script','tests/fidelityfx_settings_suite.gd')},
    @{name='physics';args=@('--headless','--script','tests/physics_suite.gd')},
    @{name='runtime';args=@('--headless','--script','tests/runtime_suite.gd')},
    @{name='pc_graphics';args=@('--headless','--script','tests/pc_graphics_suite.gd')}
)
foreach ($fsrCase in $fsrCases) {
    $fsrLog = Join-Path $fsrRoot ("artifacts/fidelityfx/"+$fsrCase.name+'.log')
    & $fsrExe --path $fsrRoot @($fsrCase.args) *> $fsrLog
    $fsrExit = $LASTEXITCODE
    $fsrErrors = @(Select-String -LiteralPath $fsrLog -Pattern '^ERROR:|SCRIPT ERROR:|^FAIL:|CrashHandlerException')
    $fsrResults += @{name=$fsrCase.name;exit_code=$fsrExit;passed=@(Select-String -LiteralPath $fsrLog -Pattern '^PASS:').Count;errors=@($fsrErrors | ForEach-Object {$_.Line})}
    $fsrResults | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $fsrRoot 'artifacts/fidelityfx/validation.json')
    Write-Output "FIDELITYFX_CHECK $($fsrCase.name) exit=$fsrExit checks=$($fsrResults[-1].passed) errors=$($fsrErrors.Count)"
    if ($fsrExit -ne 0 -or $fsrErrors.Count) {
        Get-Content -LiteralPath $fsrLog -Tail 35
        exit 1
    }
}
