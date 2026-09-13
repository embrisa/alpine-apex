[CmdletBinding(DefaultParameterSetName='Run')]
param(
    [Parameter(Mandatory,ParameterSetName='Run')][string]$Scenario,
    [Parameter(Mandatory,ParameterSetName='List')][switch]$List,
    [Parameter(ParameterSetName='Run')][ValidateRange(0.25,60)][double]$Seconds,
    [Parameter(ParameterSetName='Run')][switch]$Capture,
    [Parameter(ParameterSetName='Run')][ValidateRange(1,30)][int]$CaptureFps = 15,
    [Parameter(ParameterSetName='Run')][ValidateSet('side','chase')][string]$View = 'side',
    [Parameter(ParameterSetName='Run')][string]$Output = '',
    [Parameter(ParameterSetName='Run')][switch]$PlanOnly,
    [Parameter(ParameterSetName='Run')][switch]$FullMountain = ($env:ALPINE_FULL_MOUNTAIN -eq '1'),
    [Parameter(ParameterSetName='Run')][string]$FullMountainReason = $env:ALPINE_FULL_MOUNTAIN_REASON
)
$ErrorActionPreference='Stop'
$scenarioRoot=Split-Path $PSScriptRoot -Parent
$catalog=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'diagnostics/scenarios.json') -Raw | ConvertFrom-Json -AsHashtable
if ($List) { $catalog.maps=(Get-Content -LiteralPath (Join-Path $scenarioRoot 'tests/fixtures/test_maps.json') -Raw | ConvertFrom-Json -AsHashtable).maps; $catalog | ConvertTo-Json -Depth 8; exit 0 }
if (-not $catalog.scenarios.ContainsKey($Scenario)) { throw "Unknown scenario '$Scenario'. Use -List." }
$spec=$catalog.scenarios[$Scenario]
. (Join-Path $PSScriptRoot 'test_world_policy.ps1')
Assert-TestWorldSelection ([bool]$FullMountain) $FullMountainReason
$mapCatalog=Get-Content -LiteralPath (Join-Path $scenarioRoot 'tests/fixtures/test_maps.json') -Raw | ConvertFrom-Json -AsHashtable
$map=$mapCatalog.maps[$spec.map]
$duration=if ($PSBoundParameters.ContainsKey('Seconds')) {$Seconds} else {$spec.seconds}
if (-not $Output) { $Output="artifacts/scenarios/$Scenario-$([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))-$([guid]::NewGuid().ToString('N').Substring(0,8))" }
$destination=[IO.Path]::GetFullPath($Output,$scenarioRoot)
$plan=@{scenario=$Scenario;description=$spec.description;seconds=$duration;capture=[bool]$Capture;capture_fps=$CaptureFps;view=$View;output=$destination;workload_mode='Shared';scope='fixture';personal_records=$false;fixture=$spec.fixture;metrics=$spec.metrics}
$plan.map=@{id=$spec.map;width_m=$map.width_m;length_m=$map.length_m;objects=@($map.objects).Count;cell_m=4;full_mountain=$false}
if ($PlanOnly) { $plan | ConvertTo-Json -Depth 8; exit 0 }
if (Test-Path -LiteralPath $destination) { throw 'Choose a new scenario output directory; existing evidence is preserved.' }
$runArgs=@('--script','scripts/diagnostics/scenario_runner.gd','--',"--scenario=$Scenario","--output=$destination","--seconds=$($duration.ToString([Globalization.CultureInfo]::InvariantCulture))","--capture-fps=$CaptureFps","--view=$View")
if ($Capture) { $runArgs+='--capture' } else { $runArgs=@('--headless')+$runArgs }
Push-Location $scenarioRoot
try {
    # The producer only writes this fresh destination and uses no session or cache.
    if ($env:ALPINE_VALIDATION_ROOT -eq $scenarioRoot) { & ./godotw.ps1 @runArgs }
    else { & ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments $runArgs -WorkloadMode Shared -ResourceKeys @("output:$destination") -Label ([IO.Path]::GetFileName($destination) -replace '[^a-zA-Z0-9_-]','_') -TimeoutSeconds 600 -FullMountain:$FullMountain -FullMountainReason $FullMountainReason }
    exit $LASTEXITCODE
} finally { Pop-Location }
