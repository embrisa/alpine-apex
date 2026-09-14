param()
$ErrorActionPreference='Stop'
Set-Location -LiteralPath (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
. ./scripts/resolve_godot_engine.ps1
if ($env:ALPINE_VALIDATION_ROOT -ne (Get-Location).Path) {
    & ./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File',$PSCommandPath) -Label rock_gravel_pack -WorkloadMode Exclusive -TimeoutSeconds 600
    exit $LASTEXITCODE
}
if ($env:ALPINE_VALIDATION_MODE -ne 'Exclusive') { throw 'Resource packing requires Exclusive admission.' }
$gravelEditor=Get-AlpineGodotEngine -ProjectRoot (Get-Location).Path -InvocationArguments @('--editor')
& $gravelEditor --headless --path (Get-Location).Path --script scripts/art/integrate_rock_gravel.gd
exit $LASTEXITCODE
