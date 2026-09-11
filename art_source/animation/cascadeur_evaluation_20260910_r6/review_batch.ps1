param([ValidateSet('Source','Production','Candidate','Tests')][string]$Stage)
$ErrorActionPreference='Stop'
$project=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$engine=Join-Path $project '.tools/godot-fsr/bin/godot.windows.template_debug.x86_64.console.exe'
$ffmpeg=Join-Path $project '.tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
function Godot([string[]]$engineArgs) {
    & $engine --path $project @engineArgs
    if($LASTEXITCODE -ne 0){throw "Godot stage failed: $engineArgs"}
}
if($Stage -eq 'Tests') {
    foreach($test in @('skier_motion_suite','skier_anatomy_suite','steep_motion_suite','compact_posture_suite','ski_attachment_suite')) {
        Godot @('--headless','--script',"tests/$test.gd")
    }
    exit 0
}
$variant=if($Stage -eq 'Source'){'source'}elseif($Stage -eq 'Production'){'production'}else{'gameplay'}
$rev="cascadeur-20260910-r6-$variant"
$folder="artifacts/pose_review/revisions/$rev"
if($Stage -ne 'Source') { Godot @('--script','tests/pose_reference_render.gd','--',"--revision=$folder") }
Godot @('--script','tests/pose_reference_render.gd','--',"--revision=$folder",'--details','--selected')
if($Stage -ne 'Source') { Godot @('--script','art_source/animation/cascadeur_evaluation_20260910_r6/gameplay_camera_render.gd','--',"--revision=$folder") }
& python scripts/pose_review/encode_videos.py --revision $rev --ffmpeg $ffmpeg
if($LASTEXITCODE -ne 0){throw 'Video encode failed'}
if($Stage -ne 'Source') {
    foreach($case in @('straight','compression','steering_left','steering_right','tuck_overlap')) {
        & $ffmpeg -hide_banner -loglevel error -n -framerate 30 -i "$folder/gameplay/$case/%04d.jpg" -frames:v 121 -c:v libx264 -threads 2 -crf 18 -pix_fmt yuv420p -movflags +faststart "$folder/videos/gameplay_$case.mp4"
        if($LASTEXITCODE -ne 0){throw "Chase encode failed $case"}
    }
}
$scenarios=if($Stage -eq 'Source'){'cascadeur_grounded'}else{'straight,compression,steering_left,steering_right,tuck_overlap'}
Godot @('--headless','--script','tests/pose_pole_mesh_audit.gd','--',"--revision=$folder","--scenarios=$scenarios")
