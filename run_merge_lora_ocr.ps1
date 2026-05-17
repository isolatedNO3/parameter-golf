param(
    [string]$Config,
    [string]$Seed
)

$ErrorActionPreference = "Stop"

$Python = if (Test-Path ".\.conda-env\python.exe") { ".\.conda-env\python.exe" } else { "python" }
$env:CONFIG = if ($Config) { $Config } elseif ($env:OCR_CONFIG) { $env:OCR_CONFIG } else { "configs/vlm_textvqa_lora_ocr8.yaml" }
$env:SEED = if ($Seed) { $Seed } elseif ($env:SEED) { $env:SEED } else { "1" }
$baseModel = if ($env:BASE_MODEL) { $env:BASE_MODEL } else { "Qwen/Qwen3-VL-2B-Instruct" }
$mergeDtype = if ($env:MERGE_DTYPE) { $env:MERGE_DTYPE } else { "float16" }

$pathScript = @"
import os, yaml
config_path = r'''$env:CONFIG'''
seed = int(r'''$env:SEED''')
with open(config_path, 'r', encoding='utf-8') as f:
    cfg = yaml.safe_load(f)
output_dir = os.environ.get('OUTPUT_DIR', cfg['output_dir']).format(seed=seed)
print(output_dir)
"@

$pathInfo = $pathScript | & $Python -
if ($LASTEXITCODE -ne 0) {
    throw "Failed to read output_dir from $env:CONFIG"
}

$outputDir = $pathInfo.Trim()
$adapterPath = Join-Path $outputDir "final"
$mergedModelPath = Join-Path $outputDir "merged"

Write-Host "[INFO] OCR merge"
Write-Host "[INFO] CONFIG: $env:CONFIG"
Write-Host "[INFO] Merging seed $($env:SEED)"
Write-Host "[INFO] Adapter: $adapterPath"
Write-Host "[INFO] Output: $mergedModelPath"
Write-Host "[INFO] PYTHON: $Python"

& $Python "merge_lora.py" `
  --base_model $baseModel `
  --adapter $adapterPath `
  --output $mergedModelPath `
  --dtype $mergeDtype
