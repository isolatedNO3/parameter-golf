param(
    [string]$Config,
    [string]$Seed,
    [string]$ModelPath,
    [switch]$UseBaseModel
)

$ErrorActionPreference = "Stop"

$Python = if (Test-Path ".\.conda-env\python.exe") { ".\.conda-env\python.exe" } else { "python" }
$LmmsEval = if (Test-Path ".\.conda-env\Scripts\lmms-eval.exe") { ".\.conda-env\Scripts\lmms-eval.exe" } else { "lmms-eval" }
$env:CONFIG = if ($Config) { $Config } elseif ($env:CONFIG) { $env:CONFIG } else { "configs/vlm_textvqa_lora.yaml" }
$env:SEED = if ($Seed) { $Seed } elseif ($env:SEED) { $env:SEED } else { "1" }
$env:USE_CACHE = if ($env:USE_CACHE) { $env:USE_CACHE } else { "false" }
$env:TASK = if ($env:TASK) { $env:TASK } else { "textvqa_val" }

$configScript = @"
import json, yaml
with open(r'''$env:CONFIG''', 'r', encoding='utf-8') as f:
    cfg = yaml.safe_load(f)
seed = int(r'''$env:SEED''')
print(json.dumps({
    "model_path": cfg["model_path"],
    "output_dir": cfg["output_dir"].format(seed=seed),
    "max_pixels": int(cfg["max_pixels"]),
    "min_pixels": int(cfg["min_pixels"]),
}))
"@

$configValues = $configScript | & $Python -
if ($LASTEXITCODE -ne 0) {
    throw "Failed to read eval config from $env:CONFIG"
}
if ([string]::IsNullOrWhiteSpace($configValues)) {
    throw "Failed to read eval config from ${env:CONFIG}: Python returned empty output"
}

$cfg = $configValues | ConvertFrom-Json

# PowerShell environment variables can exist but still be an empty string.  In
# that case lmms-eval receives `min_pixels=` and qwen3_vl.py later crashes on
# int("").  Keep validated local values and pass those to --model_args.
$maxPixels = if ([string]::IsNullOrWhiteSpace($env:MAX_PIXELS)) { [string]$cfg.max_pixels } else { $env:MAX_PIXELS.Trim() }
$minPixels = if ([string]::IsNullOrWhiteSpace($env:MIN_PIXELS)) { [string]$cfg.min_pixels } else { $env:MIN_PIXELS.Trim() }

$parsedMaxPixels = 0
$parsedMinPixels = 0
if (-not [int]::TryParse($maxPixels, [ref]$parsedMaxPixels)) {
    throw "MAX_PIXELS must be an integer, got '$maxPixels'"
}
if (-not [int]::TryParse($minPixels, [ref]$parsedMinPixels)) {
    throw "MIN_PIXELS must be an integer, got '$minPixels'"
}

$env:MAX_PIXELS = [string]$parsedMaxPixels
$env:MIN_PIXELS = [string]$parsedMinPixels

if ($ModelPath) {
    $env:MODEL_PATH = $ModelPath
} elseif ($UseBaseModel) {
    $env:MODEL_PATH = $cfg.model_path
} elseif ($env:MODEL_PATH) {
    $env:MODEL_PATH = $env:MODEL_PATH
} else {
    $env:MODEL_PATH = Join-Path $cfg.output_dir "merged"
}

Write-Host "[INFO] CONFIG: $env:CONFIG"
Write-Host "[INFO] SEED: $env:SEED"
Write-Host "[INFO] MODEL_PATH: $env:MODEL_PATH"
Write-Host "[INFO] TASK: $env:TASK"
Write-Host "[INFO] MAX_PIXELS: $env:MAX_PIXELS"
Write-Host "[INFO] MIN_PIXELS: $env:MIN_PIXELS"
Write-Host "[INFO] OUTPUT_PATH: ./results/textvqa"
Write-Host "[INFO] PYTHON: $Python"
Write-Host "[INFO] LMMS_EVAL: $LmmsEval"

& $Python -c "import torch; print('CUDA available:', torch.cuda.is_available()); [print(f'  GPU {i}: {torch.cuda.get_device_name(i)}') for i in range(torch.cuda.device_count())]"

$modelArgs = "pretrained=${env:MODEL_PATH},attn_implementation=eager,device=cuda,max_pixels=${env:MAX_PIXELS},min_pixels=${env:MIN_PIXELS},use_cache=${env:USE_CACHE},device_map=cuda"
Write-Host "[INFO] MODEL_ARGS: $modelArgs"

& $LmmsEval eval `
  --model qwen3_vl `
  --model_args $modelArgs `
  --tasks $env:TASK `
  --batch_size 1 `
  --output_path "./results/textvqa"
