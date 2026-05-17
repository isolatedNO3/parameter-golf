#!/bin/bash
set -euo pipefail

if [ -z "${PYTHON:-}" ]; then
  if [ -x ".conda-env/bin/python" ]; then
    PYTHON=".conda-env/bin/python"
  elif command -v python3 >/dev/null 2>&1; then
    PYTHON="python3"
  else
    PYTHON="python"
  fi
fi

if [ -z "${ACCELERATE:-}" ]; then
  if [ -x ".conda-env/bin/accelerate" ]; then
    ACCELERATE=".conda-env/bin/accelerate"
  else
    ACCELERATE="accelerate"
  fi
fi

export WANDB_DISABLED=true
export CONFIG=${1:-${OCR_CONFIG:-${CONFIG:-configs/vlm_textvqa_lora_ocr8.yaml}}}
export SEED=${SEED:-1}
export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0}

echo "[INFO] OCR train"
echo "[INFO] CONFIG: ${CONFIG}"
echo "[INFO] SEED: ${SEED}"
echo "[INFO] PYTHON: ${PYTHON}"
echo "[INFO] ACCELERATE: ${ACCELERATE}"

"${PYTHON}" - <<'PY'
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
    print(f"[ERROR] Run first: SEED={seed} CONFIG={config_path} bash run_prepare_ocr.sh", file=sys.stderr)
    sys.exit(1)
PY

GPU_COUNT=$("${PYTHON}" - <<'PY'
import torch
print(torch.cuda.device_count() if torch.cuda.is_available() else 0)
PY
)

if [ "${GPU_COUNT}" -ge 2 ]; then
  echo "[INFO] Detected ${GPU_COUNT} GPUs, launching distributed training"
  "${ACCELERATE}" launch --num_processes "${GPU_COUNT}" --multi_gpu --mixed_precision fp16 train_textvqa_qwen3vl.py --config "${CONFIG}"
elif [ "${GPU_COUNT}" -eq 1 ]; then
  echo "[INFO] Detected 1 GPU, launching single-GPU training"
  "${ACCELERATE}" launch --num_processes 1 --mixed_precision fp16 train_textvqa_qwen3vl.py --config "${CONFIG}"
else
  echo "[ERROR] No CUDA GPU detected. This training script requires a GPU." >&2
  exit 1
fi
