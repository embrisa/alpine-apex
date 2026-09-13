param([ValidateSet('procedural','original')][string]$Mode='procedural',[switch]$Capture,
    [switch]$FullMountain = ($env:ALPINE_FULL_MOUNTAIN -eq '1'),
    [string]$FullMountainReason = $env:ALPINE_FULL_MOUNTAIN_REASON
)
$ErrorActionPreference='Stop'
$sfxRoot=Split-Path $PSScriptRoot -Parent
$sfxEngine=$env:GODOT_BIN
if (-not $sfxEngine) {
    $sfxEngine=(Get-ChildItem "$env:LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot*_console.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
$sfxLabel="sfx_$Mode"+$(if ($Capture) {'_capture'} else {'_benchmark'})
$sfxArgs=@('--path',$sfxRoot,'--script','tests/sfx_descent.gd','--','--version=12','--face=0','--side=-1',
    '--weather=clear',"--sfx-mode=$Mode",'--wind-mode=procedural',"--benchmark-label=$sfxLabel",'--benchmark-resolution=3840x2160',
    '--graphics-quality=high','--render-scale=0.75','--upscaler=fsr2','--fps-limit=120','--terrain-gi=off','--ui-staged-loading')
if ($Capture) {$sfxArgs+='--sfx-capture'}
& (Join-Path $PSScriptRoot 'run_guarded.ps1') -FilePath $sfxEngine -Arguments $sfxArgs -Label $sfxLabel -TimeoutSeconds 900 -CollectGpuMemory -FullMountain:$FullMountain -FullMountainReason $FullMountainReason
exit $LASTEXITCODE
