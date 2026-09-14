[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('slopes','rocks','vegetation','mixed','gravel')][string]$Map,
    [ValidateRange(4,10)][int]$Seconds=6,
    [ValidateRange(1,5)][int]$Repetitions=3,
    [ValidateSet('1280x720','1920x1080','2560x1440','3840x2160')][string]$Resolution='3840x2160',
    [ValidateSet('auto','fsr4','fsr3','fsr2','native')][string]$Upscaler='auto',
    [ValidateSet('0.5','0.67','0.75','1.0')][string]$RenderScale='0.75',
    [ValidateSet(0,60,120)][int]$FrameCap=0,
    [ValidateSet('riding','scenery')][string]$Camera='scenery',
    [ValidateSet('all','off','dense','sparse')][string]$Gravel='all',
    [switch]$Capture,
    [switch]$PlanOnly,
    [string]$Output=''
)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
$catalog=Get-Content -LiteralPath (Join-Path $taskRoot 'tests/fixtures/performance_maps.json') -Raw | ConvertFrom-Json -AsHashtable
$spec=$catalog.maps["perf-$Map"]
if (-not $spec) { throw "Missing performance map perf-$Map; no mountain fallback is allowed." }
if ($Capture) { $Repetitions=1 }
if (-not $Output) { $Output="artifacts/targeted_performance/$Map-$([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))-$([guid]::NewGuid().ToString('N').Substring(0,8))" }
$destination=[IO.Path]::GetFullPath($Output,$taskRoot)
$mode='FpsCritical' # Native capture runs also reserve the GPU exclusively.
$plan=@{map="perf-$Map";width_m=$spec.width_m;length_m=$spec.length_m;cell_m=4;height_samples=8385;objects=@($spec.objects).Count;trees=@($spec.objects | Where-Object tree).Count;rocks=@($spec.objects | Where-Object kind -eq 'mineral').Count;design=$spec.design;full_mountain=$false;seconds=$Seconds;repetitions=$Repetitions;warmup_seconds=3;workload_mode=$mode;resolution=$Resolution;quality='High';render_scale=$RenderScale;upscaler=$Upscaler;frame_cap=$FrameCap;capture=[bool]$Capture;camera=$Camera;gravel=$Gravel;output=$destination}
if ($PlanOnly) { $plan | ConvertTo-Json -Depth 6; exit 0 }
if (Test-Path -LiteralPath $destination) { throw 'Choose a fresh output directory; existing evidence is preserved.' }
if ($env:ALPINE_VALIDATION_ROOT -ne $taskRoot) {
    $child=@('-NoProfile','-File',(Join-Path $PSScriptRoot 'benchmark_targeted.ps1'),'-Map',$Map,'-Seconds',"$Seconds",'-Repetitions',"$Repetitions",'-Resolution',$Resolution,'-Upscaler',$Upscaler,'-RenderScale',$RenderScale,'-FrameCap',"$FrameCap",'-Camera',$Camera,'-Gravel',$Gravel,'-Output',$destination)
    if ($Capture) { $child+='-Capture' }
    & (Join-Path $PSScriptRoot 'run_guarded.ps1') -FilePath pwsh -Arguments $child -Label ([IO.Path]::GetFileName($destination) -replace '[^a-zA-Z0-9_-]','_') -WorkloadMode $mode -ResourceKeys @("output:$destination") -TimeoutSeconds 1200
    exit $LASTEXITCODE
}
if (-not $Capture -and $env:ALPINE_VALIDATION_MODE -ne 'FpsCritical') { throw 'Targeted FPS measurements require an owning FpsCritical guard.' }
New-Item -ItemType Directory -Path $destination | Out-Null
$plan | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $destination 'plan.json')
$rows=@()
$allStarted=[Diagnostics.Stopwatch]::StartNew()
for ($trial=1;$trial -le $Repetitions;$trial++) {
    $trialOutput=Join-Path $destination "trial-$trial"
    $arguments=@('--script','tests/targeted_performance.gd','--',"--map=perf-$Map","--output=$trialOutput","--seconds=$Seconds","--benchmark-resolution=$Resolution",'--graphics-quality=high',"--render-scale=$RenderScale","--upscaler=$Upscaler","--fps-limit=$FrameCap",'--terrain-gi=off','--frame-generation=off','--benchmark-no-captures',"--gravel=$Gravel")
    if ($Capture) { $arguments+='--capture-map' }
    if ($Camera -eq 'scenery') { $arguments+='--scenery-camera' }
    $trialStarted=[Diagnostics.Stopwatch]::StartNew()
    Push-Location $taskRoot
    try { & ./godotw.ps1 @arguments; $code=$LASTEXITCODE } finally { Pop-Location }
    if ($code -ne 0) { throw "Targeted $Map trial $trial failed with exit $code; preserve its evidence." }
    $row=Get-Content -LiteralPath (Join-Path $trialOutput 'results.json') -Raw | ConvertFrom-Json -AsHashtable
    if (@($row.failures).Count -or -not $row.stable_sources -or (-not $Capture -and -not $row.performance_evidence)) { throw "Targeted $Map trial $trial did not complete valid coverage." }
    if ($rows.Count) {
        $first=$rows[0]
        $sameSources=$first.source_hashes.Count -eq $row.source_hashes.Count
        foreach ($key in $first.source_hashes.Keys) { $sameSources=$sameSources -and ($first.source_hashes[$key] -ceq $row.source_hashes[$key]) }
        if (-not $sameSources -or $first.engine_sha256 -cne $row.engine_sha256 -or $first.map.identity -cne $row.map.identity -or
            ($first.actual_pixels -join 'x') -ne ($row.actual_pixels -join 'x') -or
            ($first.graphics | ConvertTo-Json -Compress -Depth 10) -cne ($row.graphics | ConvertTo-Json -Compress -Depth 10)) {
            throw 'Targeted trials changed source, engine, map, resolution or graphics; do not combine them.'
        }
    }
    $row.process_total_seconds=$trialStarted.Elapsed.TotalSeconds
    $rows+=$row
}
function Median($values) { $sorted=@($values | Sort-Object); ($sorted[[int][Math]::Floor(($sorted.Count-1)/2)]+$sorted[[int][Math]::Floor($sorted.Count/2)])/2 }
$summary=@{schema=1;plan=$plan;trials=$rows;total_seconds=$allStarted.Elapsed.TotalSeconds;median_setup_seconds=(Median @($rows | ForEach-Object setup_seconds));median_process_total_seconds=(Median @($rows | ForEach-Object process_total_seconds));performance_evidence=(-not $Capture);scope='targeted_local_rendering';human_acceptance=$false}
if (-not $Capture) {
    $summary.median_average_fps=Median @($rows | ForEach-Object average_fps)
    $summary.median_p95_frame_ms=Median @($rows | ForEach-Object {$_.frame_ms.p95})
    $summary.median_p99_frame_ms=Median @($rows | ForEach-Object {$_.frame_ms.p99})
}
$summary | ConvertTo-Json -Depth 25 | Set-Content -LiteralPath (Join-Path $destination 'summary.json')
Write-Output "TARGETED_BENCHMARK_COMPLETE map=$Map trials=$Repetitions output=$destination"
