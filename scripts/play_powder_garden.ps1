& (Join-Path (Split-Path $PSScriptRoot -Parent) 'godotw.ps1') --script tests/powder_garden.gd '--' --graphics-quality=high --render-scale=0.75 --upscaler=fsr2 --fps-limit=120 --terrain-gi=off
exit $LASTEXITCODE
