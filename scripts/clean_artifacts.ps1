[CmdletBinding(SupportsShouldProcess)]
param(
    # Existing repository-relative artifact paths to retain. A kept directory
    # retains its entire subtree; a kept file retains only that file.
    [string[]]$KeepPath = @(),
    # Existing repository-relative artifact paths to inspect/delete. Omit for
    # the original whole-artifacts cleanup scope.
    [string[]]$TargetPath = @()
)
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

function Resolve-CleanupArtifactPath {
    param(
        [Parameter(Mandatory)][string]$Value,
        [Parameter(Mandatory)][string]$Role
    )
    if ([string]::IsNullOrWhiteSpace($Value) -or [IO.Path]::IsPathRooted($Value)) {
        throw "$Role path must be a non-empty repository-relative path beneath artifacts: $Value"
    }
    $normalizedInput = $Value.Replace('/', [IO.Path]::DirectorySeparatorChar).Replace('\\', [IO.Path]::DirectorySeparatorChar)
    $requiredPrefix = 'artifacts' + [IO.Path]::DirectorySeparatorChar
    if (-not $normalizedInput.Equals('artifacts', [StringComparison]::OrdinalIgnoreCase) -and
        -not $normalizedInput.StartsWith($requiredPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Role path must be beneath artifacts: $Value"
    }
    $full = [IO.Path]::GetFullPath((Join-Path $cleanupProject $normalizedInput))
    if (-not $full.Equals($cleanupRoot, [StringComparison]::OrdinalIgnoreCase) -and
        -not $full.StartsWith($cleanupPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Role path escapes artifacts: $Value"
    }
    if (-not (Test-Path -LiteralPath $full)) { throw "$Role path does not exist: $Value" }
    return $full
}

$cleanupRequestedKeeps = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($path in $KeepPath) {
    $full = Resolve-CleanupArtifactPath -Value $path -Role 'Keep'
    if ($full.Equals($cleanupRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Keep path cannot be artifacts itself; omit TargetPath to preview the whole root without deleting it.'
    }
    [void]$cleanupRequestedKeeps.Add($full)
}

$cleanupRequestedTargets = [Collections.Generic.List[string]]::new()
if ($TargetPath.Count -eq 0) {
    $cleanupRequestedTargets.Add($cleanupRoot)
} else {
    foreach ($path in $TargetPath) {
        $full = Resolve-CleanupArtifactPath -Value $path -Role 'Target'
        if ($full -ne $cleanupRoot -and ([IO.Path]::GetFileName($full) -in $cleanupKeep) -and
            [IO.Path]::GetDirectoryName($full).Equals($cleanupRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Target path is a retained artifact control entry: $path"
        }
        if (-not $cleanupRequestedTargets.Contains($full)) {
            $cleanupRequestedTargets.Add($full)
        }
    }
}
$cleanupTargets = [Collections.Generic.List[string]]::new()
foreach ($candidate in @($cleanupRequestedTargets | Sort-Object Length)) {
    $covered = $false
    foreach ($existing in $cleanupTargets) {
        if ($candidate.Equals($existing, [StringComparison]::OrdinalIgnoreCase) -or
            $candidate.StartsWith($existing + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            $covered = $true
            break
        }
    }
    if (-not $covered) { $cleanupTargets.Add($candidate) }
}

function Test-CleanupKeep {
    param([Parameter(Mandatory)][string]$Path)
    foreach ($keep in $cleanupRequestedKeeps) {
        if ($Path.Equals($keep, [StringComparison]::OrdinalIgnoreCase) -or
            $Path.StartsWith($keep + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Test-CleanupRootControlEntry {
    param([Parameter(Mandatory)][IO.FileSystemInfo]$Entry)
    return [IO.Path]::GetDirectoryName($Entry.FullName).Equals($cleanupRoot, [StringComparison]::OrdinalIgnoreCase) -and $Entry.Name -in $cleanupKeep
}

function Assert-CleanupPath {
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $full.Equals($cleanupRoot, [StringComparison]::OrdinalIgnoreCase) -and
        -not $full.StartsWith($cleanupPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Cleanup target is outside artifacts: $full"
    }
    return $full
}

function Remove-CleanupEntry {
    param([Parameter(Mandatory)][string]$Path)
    $full = Assert-CleanupPath -Path $Path
    if (Test-CleanupKeep -Path $full) { return $false }
    $entry = Get-Item -LiteralPath $full -Force
    if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        # No -Recurse: unlink the entry itself, never its target contents.
        Remove-Item -LiteralPath $full -Force
        return $true
    }
    if (-not $entry.PSIsContainer) {
        Remove-Item -LiteralPath $full -Force
        return $true
    }
    $allRemoved = $true
    foreach ($child in Get-ChildItem -LiteralPath $full -Force) {
        if (-not (Remove-CleanupEntry -Path $child.FullName)) { $allRemoved = $false }
    }
    if ($allRemoved) {
        Remove-Item -LiteralPath $full -Force
        return $true
    }
    return $false
}

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
    foreach ($target in $cleanupTargets) { $cleanupPending.Push($target) }
    $cleanupBytes = [int64]0
    $cleanupFiles = 0
    while ($cleanupPending.Count) {
        $pendingPath = $cleanupPending.Pop()
        $pendingEntry = Get-Item -LiteralPath $pendingPath -Force
        if (-not $pendingEntry.PSIsContainer) {
            $pendingChildren = @($pendingEntry)
        } else {
            $pendingChildren = @(Get-ChildItem -LiteralPath $pendingPath -Force)
        }
        foreach ($entry in $pendingChildren) {
            if (Test-CleanupRootControlEntry -Entry $entry) { continue }
            $full = Assert-CleanupPath -Path $entry.FullName
            if (Test-CleanupKeep -Path $full) { continue }
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
    $cleanupTargetText = (($cleanupTargets | ForEach-Object { $_.Substring($cleanupProject.Length + 1) }) -join ', ')
    Write-Output ("Artifacts: {0} deletable files, {1:N2} GiB logical size across {2}. Keeping {3} requested path(s). Hard links may share physical storage." -f $cleanupFiles,($cleanupBytes/1GB),$cleanupTargetText,$cleanupRequestedKeeps.Count)
    if ($cleanupFiles -eq 0 -and $cleanupLinks.Count -eq 0) { return }
    if ($PSCmdlet.ShouldProcess($cleanupTargetText, "Delete generated output while retaining $($cleanupRequestedKeeps.Count) requested path(s)")) {
        foreach ($target in $cleanupTargets) {
            if ($target.Equals($cleanupRoot, [StringComparison]::OrdinalIgnoreCase)) {
                foreach ($entry in Get-ChildItem -LiteralPath $cleanupRoot -Force) {
                    if (-not (Test-CleanupRootControlEntry -Entry $entry)) {
                        [void](Remove-CleanupEntry -Path $entry.FullName)
                    }
                }
            } else {
                [void](Remove-CleanupEntry -Path $target)
            }
        }
        Write-Output 'Selected generated artifacts cleared.'
    }
} finally { $cleanupLock.Dispose() }
