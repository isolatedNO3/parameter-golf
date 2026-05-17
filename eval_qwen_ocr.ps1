param(
    [string]$Config,
    [string]$Seed,
    [string]$ModelPath,
    [switch]$UseBaseModel
)

$ErrorActionPreference = "Stop"

$ocrConfig = if ($Config) { $Config } elseif ($env:OCR_CONFIG) { $env:OCR_CONFIG } else { "configs/vlm_textvqa_lora_ocr8.yaml" }
$ocrSeed = if ($Seed) { $Seed } elseif ($env:SEED) { $env:SEED } else { "1" }
$env:TASK = if ($env:OCR_TASK) { $env:OCR_TASK } else { "textvqa_val_ocr8" }

Write-Host "[INFO] OCR eval"

if ($ModelPath) {
    & ".\eval_qwen.ps1" -Config $ocrConfig -Seed $ocrSeed -ModelPath $ModelPath
} elseif ($UseBaseModel) {
    Remove-Item Env:MODEL_PATH -ErrorAction SilentlyContinue
    & ".\eval_qwen.ps1" -Config $ocrConfig -Seed $ocrSeed -UseBaseModel
} else {
    # Do not inherit a stale MODEL_PATH from previous baseline eval commands.
    # With MODEL_PATH unset, eval_qwen.ps1 will use the OCR config output_dir:
    # ./outputs/textvqa_qwen3vl_lora_ocr8_seed{seed}/merged
    Remove-Item Env:MODEL_PATH -ErrorAction SilentlyContinue
    & ".\eval_qwen.ps1" -Config $ocrConfig -Seed $ocrSeed
}
