param(
    [Parameter(Mandatory)][string]$Script,
    [string[]]$UserArguments = @(),
    [string]$Label = 'planted_check',
    [switch]$Native,
    [int]$TimeLimit = 900
,
    [switch]$FullMountain = ($env:ALPINE_FULL_MOUNTAIN -eq '1'),
    [string]$FullMountainReason = $env:ALPINE_FULL_MOUNTAIN_REASON
)
$ErrorActionPreference = 'Stop'
$snowProject = Split-Path $PSScriptRoot -Parent
$snowDeadline = (Get-Date).AddMinutes(15)
while ($true) {
    try {
        $snowSlot = [IO.File]::Open((Join-Path $snowProject 'artifacts/validation.lock'),'OpenOrCreate','ReadWrite','None')
        $snowSlot.Dispose()
        break
    } catch {
        if ((Get-Date) -ge $snowDeadline) { throw }
        Start-Sleep -Seconds 2
    }
}
$snowArgs = @('--script',$Script)
if (-not $Native) { $snowArgs = @('--headless') + $snowArgs }
if ($UserArguments.Count) { $snowArgs += @('--') + $UserArguments }
& "$PSScriptRoot/run_guarded.ps1" -FilePath "$snowProject/godotw.ps1" -Arguments $snowArgs -Label $Label -TimeoutSeconds $TimeLimit -CollectGpuMemory:$Native -FullMountain:$FullMountain -FullMountainReason $FullMountainReason
exit $LASTEXITCODE
