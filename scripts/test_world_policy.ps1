# One map-selection policy for the guard, batch runner and diagnostic wrappers.
function Get-TestWorldPlan([string[]]$Producers) {
    $root = Split-Path $PSScriptRoot -Parent
    $catalog = Get-Content -LiteralPath (Join-Path $root 'tests/fixtures/test_maps.json') -Raw | ConvertFrom-Json -AsHashtable
    $plans = foreach ($producer in $Producers) {
        $name = $producer.Replace('res://','').Replace('\','/')
        if ([IO.Path]::IsPathRooted($name)) { $name = [IO.Path]::GetRelativePath($root,$name).Replace('\','/') }
        $spec = $catalog.producers[$name]
        if (-not $spec) { $spec = @{maps=@();full_mountain=$false;coverage='Producer-owned inline fixtures; runtime mountain gate enforced.'} }
        $maps = foreach ($id in $spec.maps) {
            $map = $catalog.maps[$id]
            @{id=$id;width_m=$map.width_m;length_m=$map.length_m;objects=@($map.objects).Count;cell_m=4}
        }
        @{producer=$name;maps=@($maps)+@($spec.additional_surfaces | Where-Object { $null -ne $_ });full_mountain=[bool]$spec.full_mountain;coverage=$spec.coverage}
    }
    return @($plans)
}

function Assert-TestWorldSelection([bool]$FullMountain,[string]$Reason,$Plans=@()) {
    $granted = $FullMountain -and -not [string]::IsNullOrWhiteSpace($Reason)
    if ($FullMountain -xor (-not [string]::IsNullOrWhiteSpace($Reason))) { throw 'Use -FullMountain and a nonempty -FullMountainReason together.' }
    if (-not $granted -and @($Plans | Where-Object full_mountain).Count) { throw 'Selected checks require -FullMountain and -FullMountainReason. Inspect -PlanOnly for coverage and smaller fixtures.' }
}

function Get-TestWorldProducers([string]$File,[string[]]$TargetArguments) {
    $items = @()
    if ($File -match '\.(gd|ps1)$') { $items += $File }
    for ($i=0;$i -lt $TargetArguments.Count-1;$i++) {
        if ($TargetArguments[$i] -in @('-File','--script','-s')) { $items += $TargetArguments[$i+1] }
    }
    return $items
}
