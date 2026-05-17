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

export CONFIG=${1:-${OCR_CONFIG:-${CONFIG:-configs/vlm_textvqa_lora_ocr8.yaml}}}
export SEED=${SEED:-1}
export TASK=${OCR_TASK:-textvqa_val_ocr8}

echo "[INFO] OCR eval"
echo "[INFO] CONFIG: ${CONFIG}"
echo "[INFO] SEED: ${SEED}"
echo "[INFO] PYTHON: ${PYTHON}"

mapfile -t CFG_VALUES < <("${PYTHON}" - <<'PY'
import os
import yaml

config_path = os.environ["CONFIG"]
with open(config_path, "r", encoding="utf-8") as f:
    cfg = yaml.safe_load(f)
seed = int(os.environ.get("SEED", cfg.get("seed", 1)))
print(os.environ.get("OUTPUT_DIR", cfg["output_dir"]).format(seed=seed))
print(int(cfg["max_pixels"]))
print(int(cfg["min_pixels"]))
PY
)

OUTPUT_DIR=${CFG_VALUES[0]}
# Avoid inheriting a stale MODEL_PATH from previous baseline eval commands.
# Use OCR_MODEL_PATH for an explicit override; otherwise default to the OCR
# merged model path.
export MODEL_PATH=${OCR_MODEL_PATH:-${OUTPUT_DIR}/merged}
export MAX_PIXELS=${MAX_PIXELS:-${CFG_VALUES[1]}}
export MIN_PIXELS=${MIN_PIXELS:-${CFG_VALUES[2]}}

CONFIG="${CONFIG}" TASK="${TASK}" MODEL_PATH="${MODEL_PATH}" MAX_PIXELS="${MAX_PIXELS}" MIN_PIXELS="${MIN_PIXELS}" bash eval_qwen.sh
