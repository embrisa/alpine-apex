$ErrorActionPreference='Stop'
$treeProject=Split-Path $PSScriptRoot -Parent
Push-Location $treeProject
try { & ./godotw.ps1 res://scenes/art/tree_gallery.tscn; exit $LASTEXITCODE }
finally { Pop-Location }
