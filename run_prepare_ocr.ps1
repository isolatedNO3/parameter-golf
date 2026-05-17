param(
    [string]$Config,
    [string]$Seed
)

$ErrorActionPreference = "Stop"

$Python = if (Test-Path ".\.conda-env\python.exe") { ".\.conda-env\python.exe" } else { "python" }
$env:CONFIG = if ($Config) { $Config } elseif ($env:OCR_CONFIG) { $env:OCR_CONFIG } else { "configs/vlm_textvqa_lora_ocr8.yaml" }
$env:SEED = if ($Seed) { $Seed } elseif ($env:SEED) { $env:SEED } else { "1" }

Write-Host "[INFO] OCR prepare"
Write-Host "[INFO] CONFIG: $env:CONFIG"
Write-Host "[INFO] SEED: $env:SEED"
Write-Host "[INFO] PYTHON: $Python"

& $Python "prepare_textvqa.py" --config $env:CONFIG
