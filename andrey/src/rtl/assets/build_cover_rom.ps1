$ErrorActionPreference = 'Stop'
$builder = Join-Path $PSScriptRoot 'build_music_rom.py'
& python $builder
if ($LASTEXITCODE -ne 0) { throw "ROM generation failed with exit code $LASTEXITCODE" }
