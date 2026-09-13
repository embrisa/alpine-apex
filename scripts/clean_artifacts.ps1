[CmdletBinding(SupportsShouldProcess)]
param()
# Delete local validation output only. Source assets, test fixtures, installed
# tools, the main Godot import cache and user:// mountain bakes are outside scope.
$ErrorActionPreference = 'Stop'
$cleanupProject = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$cleanupRoot = Join-Path $cleanupProject 'artifacts'
if (-not (Test-Path -LiteralPath $cleanupRoot)) { return }
if ((Get-Item -LiteralPath $cleanupRoot -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'Refusing cleanup through an artifacts directory link.'
}
$cleanupPrefix = $cleanupRoot + [IO.Path]::DirectorySeparatorChar
# Keep the directory/import marker and its instructions available in a project copy.
$cleanupKeep = @('.gdignore', 'README.md', 'validation.lock', 'validation_leases')
$cleanupLock = [IO.File]::Open((Join-Path $cleanupRoot 'validation.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
try {
    $cleanupActive = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -match '^Godot($|[_.-])|^blender$'
    })
    if ($cleanupActive.Count) { throw 'Close Godot/Blender or wait for validation before cleaning artifacts.' }
    # Inspect every descendant before any recursive deletion. Unlink junctions
    # separately without following them into shared assets or another project copy.
    $cleanupLinks = [Collections.Generic.List[string]]::new()
    $cleanupPending = [Collections.Generic.Stack[string]]::new()
    $cleanupPending.Push($cleanupRoot)
    $cleanupBytes = [int64]0
    $cleanupFiles = 0
    while ($cleanupPending.Count) {
        foreach ($entry in Get-ChildItem -LiteralPath $cleanupPending.Pop() -Force) {
            if ($entry.Parent.FullName -eq $cleanupRoot -and $entry.Name -eq 'validation_leases') { continue }
            $full = [IO.Path]::GetFullPath($entry.FullName)
            if (-not $full.StartsWith($cleanupPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Cleanup target is outside artifacts: $full"
            }
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $cleanupLinks.Add($full)
                continue
            }
            if ($entry.PSIsContainer) { $cleanupPending.Push($full) }
            elseif ($entry.DirectoryName -ne $cleanupRoot -or $entry.Name -notin $cleanupKeep) {
                $cleanupBytes += $entry.Length
                $cleanupFiles++
            }
        }
    }
    Write-Output ("Artifacts: {0} disposable files, {1:N2} GiB logical size. Hard links may share physical storage." -f $cleanupFiles,($cleanupBytes/1GB))
    if ($cleanupFiles -eq 0 -and $cleanupLinks.Count -eq 0) { return }
    if ($PSCmdlet.ShouldProcess($cleanupRoot, 'Delete all generated output, including reports, comparisons, captures and project snapshots')) {
        foreach ($link in $cleanupLinks) {
            # No -Recurse: remove the link itself, never its target contents.
            Remove-Item -LiteralPath $link -Force
        }
        foreach ($target in Get-ChildItem -LiteralPath $cleanupRoot -Force | Where-Object Name -NotIn $cleanupKeep) {
            $resolved = (Resolve-Path -LiteralPath $target.FullName).Path
            if (-not $resolved.StartsWith($cleanupPrefix, [StringComparison]::OrdinalIgnoreCase) -or
                $target.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Unsafe cleanup target: $resolved"
            }
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
        Write-Output 'Generated artifacts cleared.'
    }
} finally { $cleanupLock.Dispose() }
