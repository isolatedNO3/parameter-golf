param(
    [string]$Config,
    [string]$Seed
)

$ErrorActionPreference = "Stop"

$Python = if (Test-Path ".\.conda-env\python.exe") { ".\.conda-env\python.exe" } else { "python" }
$Accelerate = if (Test-Path ".\.conda-env\Scripts\accelerate.exe") { ".\.conda-env\Scripts\accelerate.exe" } else { "accelerate" }
$env:WANDB_DISABLED = "true"
$env:CONFIG = if ($Config) { $Config } elseif ($env:OCR_CONFIG) { $env:OCR_CONFIG } else { "configs/vlm_textvqa_lora_ocr8.yaml" }
$env:SEED = if ($Seed) { $Seed } elseif ($env:SEED) { $env:SEED } else { "1" }
$env:CUDA_VISIBLE_DEVICES = if ($env:CUDA_VISIBLE_DEVICES) { $env:CUDA_VISIBLE_DEVICES } else { "0" }
$env:HTTP_PROXY = ""
$env:HTTPS_PROXY = ""
$env:ALL_PROXY = ""
$env:GIT_HTTP_PROXY = ""
$env:GIT_HTTPS_PROXY = ""

Write-Host "[INFO] OCR train"
Write-Host "[INFO] CONFIG: $env:CONFIG"
Write-Host "[INFO] SEED: $env:SEED"
Write-Host "[INFO] PYTHON: $Python"
Write-Host "[INFO] ACCELERATE: $Accelerate"

$precheck = @'
import os
import sys
import yaml

config_path = os.environ["CONFIG"]
with open(config_path, "r", encoding="utf-8") as f:
    cfg = yaml.safe_load(f)
seed = int(os.environ.get("SEED", cfg.get("seed", 1)))
prepared = os.environ.get("PREPARED_DATA_DIR", cfg["prepared_data_dir"]).format(seed=seed)
if not os.path.isdir(prepared):
    print(f"[ERROR] Prepared dataset not found: {prepared}", file=sys.stderr)
    print(f"[ERROR] Run first: .\\run_prepare_ocr.ps1 -Seed {seed}", file=sys.stderr)
    sys.exit(1)
'@

$precheck | & $Python -
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$gpuCount = & $Python -c "import torch; print(torch.cuda.device_count() if torch.cuda.is_available() else 0)"
$gpuCount = [int]$gpuCount

if ($gpuCount -ge 2) {
    Write-Host "[INFO] Detected $gpuCount GPUs, launching distributed training"
    & $Accelerate launch --num_processes $gpuCount --multi_gpu --mixed_precision fp16 "train_textvqa_qwen3vl.py" --config $env:CONFIG
} elseif ($gpuCount -eq 1) {
    Write-Host "[INFO] Detected 1 GPU, launching single-GPU training"
    & $Accelerate launch --num_processes 1 --mixed_precision fp16 "train_textvqa_qwen3vl.py" --config $env:CONFIG
} else {
    throw "No CUDA GPU detected. This training script requires a GPU."
}
