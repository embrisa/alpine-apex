param([ValidateSet('Capture','Tests','Selected','Full','Audit','Videos','Chase')][string]$Stage)
$ErrorActionPreference='Stop'
$reviewProject=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$reviewEngine=Join-Path $reviewProject '.tools/godot-fsr/bin/godot.windows.template_debug.x86_64.console.exe'
function Godot([string[]]$engineArgs) {
    & $reviewEngine --path $reviewProject @engineArgs
    if($LASTEXITCODE -ne 0){throw "Godot stage failed: $engineArgs"}
}
if($Stage -eq 'Capture'){
    Godot @('--headless','--script','art_source/animation/cascadeur_carving_20260910_r7/gameplay_capture.gd')
    Godot @('--headless','--script','art_source/animation/cascadeur_carving_20260910_r7/preview_capture.gd')
    exit 0
}
if($Stage -eq 'Tests'){
    Godot @('--headless','--script','tests/cascadeur_r7_playtest/motion_suite.gd')
    foreach($test in @('skier_motion_suite','skier_anatomy_suite','steep_motion_suite','compact_posture_suite','ski_attachment_suite')){
        Godot @('--headless','--script',"tests/$test.gd")
    }
    exit 0
}
$reviewFFmpeg=Join-Path $reviewProject '.tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
foreach($variant in @('source','production','gameplay')){
    $revision="cascadeur-20260910-r7-$variant"
    $folder="artifacts/pose_review/revisions/$revision"
    if($Stage -in @('Selected','Full')){
        $renderArgs=@('--script','tests/pose_reference_render.gd','--',"--revision=$folder")
        if($Stage -eq 'Selected'){$renderArgs+='--selected'}
        Godot $renderArgs
        if($Stage -eq 'Full'){Godot @('--script','tests/pose_reference_render.gd','--',"--revision=$folder",'--details','--selected')}
    }
    if($Stage -eq 'Audit'){
        $cases=if($variant -eq 'source'){'cascadeur_carving'}else{'straight,steering_left,steering_right,carve_reversal,carve_taps,tuck_turn'}
        Godot @('--headless','--script','tests/pose_pole_mesh_audit.gd','--',"--revision=$folder","--scenarios=$cases")
    }
    if($Stage -eq 'Videos'){
        & python scripts/pose_review/encode_videos.py --revision $revision --ffmpeg $reviewFFmpeg
        if($LASTEXITCODE -ne 0){throw 'Video encoding failed'}
    }
    if($Stage -eq 'Chase' -and $variant -ne 'source'){
        Godot @('--script','art_source/animation/cascadeur_carving_20260910_r7/gameplay_camera_render.gd','--',"--revision=$folder")
        & $reviewFFmpeg -hide_banner -loglevel error -n -framerate 30 -i "$folder/gameplay/carve_reversal/%04d.jpg" -frames:v 121 -c:v libx264 -threads 2 -crf 18 -pix_fmt yuv420p -movflags +faststart "$folder/videos/gameplay_carve_reversal.mp4"
        if($LASTEXITCODE -ne 0){throw 'Chase video encoding failed'}
    }
}
