param(
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateSet('side','chase','first_person')][string]$View = 'side',
    [switch]$Uneven,
    [switch]$Tuck,
    [switch]$Terrain,
    [string]$ReferenceAssist = ""
)
# Native final-pose capture without taking focus or changing personal settings.
$ErrorActionPreference = 'Stop'
$captureRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$captureOutput = [IO.Path]::GetFullPath($OutputDirectory,$captureRoot)
$capturePrefix = (Join-Path $captureRoot 'artifacts') + [IO.Path]::DirectorySeparatorChar
if (-not $captureOutput.StartsWith($capturePrefix,[StringComparison]::OrdinalIgnoreCase) -or
    (Test-Path -LiteralPath $captureOutput)) { throw 'Choose a fresh output directory under artifacts.' }
New-Item -ItemType Directory -Path $captureOutput | Out-Null
$captureProject = Join-Path $captureOutput '_capture_project'
New-Item -ItemType Directory -Path $captureProject | Out-Null
$captureCode = 1
try {
    foreach ($folder in @('.godot','addons','assets','config','scripts','tests','artifacts')) {
        New-Item -ItemType Junction -Path (Join-Path $captureProject $folder) -Target (Join-Path $captureRoot $folder) | Out-Null
    }
    $config = [IO.File]::ReadAllText((Join-Path $captureRoot 'project.godot'))
    $config = $config.Replace('[display]',"[display]`nwindow/size/no_focus=true`nwindow/size/initial_position_type=0`nwindow/size/initial_position=Vector2i(-2000, -1200)")
    [IO.File]::WriteAllText((Join-Path $captureProject 'project.godot'),$config,[Text.UTF8Encoding]::new($false))
    foreach ($file in @('main.tscn','icon.svg')) { Copy-Item -LiteralPath (Join-Path $captureRoot $file) -Destination $captureProject }
    $relativeOutput = [IO.Path]::GetRelativePath($captureRoot,$captureOutput).Replace('\','/')
    $captureScript = if ($Terrain) { 'tests/terrain_settle_capture.gd' } else { 'tests/small_landing_capture.gd' }
    $captureArgs = @('--path',$captureProject,'--windowed','--resolution','1280x720','--position','-2000,-1200','--audio-driver','Dummy','--script',$captureScript,'--',"--output=$relativeOutput","--view=$View")
    if ($ReferenceAssist) {
        if (-not $Terrain) { throw 'ReferenceAssist requires Terrain.' }
        $referencePath = [IO.Path]::GetFullPath($ReferenceAssist,$captureRoot)
        if (-not $referencePath.StartsWith($capturePrefix,[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $referencePath -PathType Leaf)) { throw 'ReferenceAssist must be a frozen source file under artifacts.' }
        $captureArgs += '--reference-assist=' + [IO.Path]::GetRelativePath($captureRoot,$referencePath).Replace('\','/')
    }
    if ($Uneven) { $captureArgs += '--uneven' }
    if ($Tuck) { $captureArgs += '--tuck' }
    & (Join-Path $PSScriptRoot 'run_guarded.ps1') -FilePath (Join-Path $captureRoot 'godotw.ps1') -Arguments $captureArgs -Label "small-landing-$View" -TimeoutSeconds 240
    $captureCode = $LASTEXITCODE
} finally {
    # Only immediate generated files/links are removed. Never recurse through a
    # junction to the shared imports, assets, scripts or another task's output.
    $projectPrefix = $captureProject + [IO.Path]::DirectorySeparatorChar
    foreach ($entry in Get-ChildItem -LiteralPath $captureProject -Force) {
        $path = [IO.Path]::GetFullPath($entry.FullName)
        if (-not $path.StartsWith($projectPrefix,[StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe capture cleanup: $path" }
        if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -or -not $entry.PSIsContainer) { Remove-Item -LiteralPath $path -Force }
    }
    if (-not (Get-ChildItem -LiteralPath $captureProject -Force)) { Remove-Item -LiteralPath $captureProject }
}
exit $captureCode
