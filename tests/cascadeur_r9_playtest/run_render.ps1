param([ValidateSet('Selected','Full','Details','Audit','Videos')][string]$Stage)
$ErrorActionPreference='Stop'
$snowProject=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$snowEngine=Join-Path $snowProject '.tools/godot-fsr/bin/godot.windows.template_debug.x86_64.console.exe'
$snowFFmpeg=Join-Path $snowProject '.tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
$snowAuditFailures=0
foreach($snowVariant in @('before','after')){
    $snowRevision="cascadeur-20260911-r9-02-$snowVariant"
    $snowFolder="artifacts/pose_review/revisions/$snowRevision"
    if($Stage -in @('Selected','Full','Details')){
        $snowArgs=@('--path',$snowProject,'--script','tests/pose_reference_render.gd','--',"--revision=$snowFolder",'--camera-size=4.1')
        if($Stage -eq 'Selected'){$snowArgs+='--selected'}
        if($Stage -eq 'Details'){$snowArgs+='--details'}
        & $snowEngine @snowArgs
        if($LASTEXITCODE -ne 0){throw 'Render failed'}
    }
    if($Stage -eq 'Audit'){
        & $snowEngine --path $snowProject --headless --script tests/pose_pole_mesh_audit.gd -- "--revision=$snowFolder" '--scenarios=straight,steering_left,steering_right,carve_reversal,carve_taps,tuck_turn'
        # Keep both audit reports even if one exposes a clothing defect.
        if($LASTEXITCODE -ne 0){$snowAuditFailures++;Write-Output "CLOTHING_FAILURE $snowVariant exit=$LASTEXITCODE; inspect report"}
    }
    if($Stage -eq 'Videos'){
        & python scripts/pose_review/encode_videos.py --revision $snowRevision --ffmpeg $snowFFmpeg
        if($LASTEXITCODE -ne 0){throw 'Encoding failed'}
    }
}
if($snowAuditFailures -gt 0){exit 1}
