$ErrorActionPreference='Stop'
$project=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
foreach($variant in @('source','gameplay')) {
    $folder=Join-Path $project "artifacts/pose_review/revisions/cascadeur-20260910-r6-$variant"
    if(Test-Path (Join-Path $folder 'sealed.json')){throw 'Sealed revision'}
    $prior=Join-Path $folder 'details_pelvis_focus'
    if(Test-Path $prior){throw 'Previous focus evidence already preserved'}
    Copy-Item -LiteralPath (Join-Path $folder 'details') -Destination $prior -Recurse
    Copy-Item -LiteralPath (Join-Path $folder 'details.json') -Destination (Join-Path $folder 'details_pelvis_focus.json')
    & "$project/.tools/godot-fsr/bin/godot.windows.template_debug.x86_64.console.exe" --path $project --script art_source/animation/cascadeur_evaluation_20260910_r6/matched_details_render.gd '--' "--revision=$folder" --details --selected
    if($LASTEXITCODE -ne 0){throw 'Matched detail renderer failed'}
    $meta=Get-Content (Join-Path $folder 'details.json') -Raw | ConvertFrom-Json
    $meta.camera_policy='Exact baseline detail camera transforms and sizes. R6 source uses R5 cameras; R6 gameplay uses production cameras. No bone or equipment change.'
    $meta | Add-Member renderer_override_sha256 (Get-FileHash (Join-Path $PSScriptRoot 'matched_details_render.gd') -Algorithm SHA256).Hash.ToLower()
    $meta | ConvertTo-Json -Depth 40 | Set-Content (Join-Path $folder 'details.json') -Encoding utf8
}
