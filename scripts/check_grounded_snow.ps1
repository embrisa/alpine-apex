param([ValidateSet('contracts','banks','carving','mountain','visual','timing','solver')][string]$Stage = 'contracts')
$ErrorActionPreference = 'Stop'
$snowProject = Split-Path $PSScriptRoot -Parent
$snowJobs = switch ($Stage) {
    'contracts' { @{script='snow_crush_suite';extra=@('--contracts');headless=$true}; @{script='snow_grounding_suite';extra=@('--contracts');headless=$true} }
    'carving' { @{script='snow_grounding_carving';extra=@();headless=$true} }
    'banks' { @{script='snow_crush_suite';extra=@();headless=$true} }
    'solver' { @{script='snow_grounding_timing';extra=@();headless=$true} }
    'mountain' { @{script='snow_grounding_mountain';extra=@();headless=$true} }
    'visual' { @{script='snow_grounding_playtest';extra=@();headless=$false} }
    'timing' { @{script='snow_grounding_playtest';extra=@('--timing');headless=$false} }
}
foreach ($snowJob in $snowJobs) {
    $snowDeadline = (Get-Date).AddMinutes(15)
    $snowArguments = @('-NoProfile','-File',(Join-Path $snowProject 'godotw.ps1'))
    if ($snowJob.headless) { $snowArguments += '--headless' }
    $snowArguments += @('--script',('tests/'+$snowJob.script+'.gd'))
    if ($snowJob.extra.Count) { $snowArguments += @('--') + $snowJob.extra }
    $snowLabel = 'snow28_'+$Stage+'_'+$snowJob.script
    do {
        $snowBusy = @(Get-CimInstance Win32_Process | Where-Object {
            ($_.Name -like 'Godot*.exe' -and $_.CommandLine -match '(--script\s|--import)') -or
            ($_.Name -eq 'blender.exe' -and $_.CommandLine -match '--background')
        })
        $snowLockFree = $false
        try {
            if (Test-Path -LiteralPath (Join-Path $snowProject 'artifacts/validation.lock')) {
                $snowProbe = [IO.File]::Open((Join-Path $snowProject 'artifacts/validation.lock'), 'Open', 'Read', 'None')
                $snowProbe.Dispose()
            }
            $snowLockFree = $true
        } catch [IO.IOException] {}
        if ((Get-Date) -gt $snowDeadline) { throw 'Other validation is still active after 15 minutes; existing processes were left running.' }
        if ($snowBusy.Count -gt 0 -or -not $snowLockFree) { Start-Sleep -Seconds 4; continue }
        try {
            & (Join-Path $PSScriptRoot 'run_guarded.ps1') -FilePath pwsh -Arguments $snowArguments -Label $snowLabel -TimeoutSeconds 1200 -CollectGpuMemory:(!$snowJob.headless)
        } catch {
            # Another queued task may acquire the shared guard after our probe.
            # Retry only resource contention; a real test failure still exits.
            if ($_.Exception.Message -like '*validation.lock*') { Start-Sleep -Seconds 2; continue }
            throw
        }
        if ($LASTEXITCODE -ne 0) {
            $snowGuard = Get-Content -LiteralPath (Join-Path $snowProject ('artifacts/guarded/'+$snowLabel+'/guard.json')) -Raw | ConvertFrom-Json
            if ($snowGuard.stop_reason -like 'Another Godot/Blender workload is active*') { Start-Sleep -Seconds 2; continue }
            exit $LASTEXITCODE
        }
        break
    } while ($true)
}
