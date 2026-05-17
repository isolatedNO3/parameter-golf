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
export BASE_MODEL=${BASE_MODEL:-Qwen/Qwen3-VL-2B-Instruct}
export MERGE_DTYPE=${MERGE_DTYPE:-float16}

OUTPUT_DIR=$("${PYTHON}" - <<'PY'
import os
import yaml

config_path = os.environ["CONFIG"]
with open(config_path, "r", encoding="utf-8") as f:
    cfg = yaml.safe_load(f)
seed = int(os.environ.get("SEED", cfg.get("seed", 1)))
print(os.environ.get("OUTPUT_DIR", cfg["output_dir"]).format(seed=seed))
PY
)

ADAPTER=${ADAPTER:-${OUTPUT_DIR}/final}
MERGED_MODEL=${MERGED_MODEL:-${OUTPUT_DIR}/merged}

echo "[INFO] OCR merge"
echo "[INFO] CONFIG: ${CONFIG}"
echo "[INFO] SEED: ${SEED}"
echo "[INFO] Adapter: ${ADAPTER}"
echo "[INFO] Output: ${MERGED_MODEL}"
echo "[INFO] PYTHON: ${PYTHON}"

"${PYTHON}" merge_lora.py \
  --base_model "${BASE_MODEL}" \
  --adapter "${ADAPTER}" \
  --output "${MERGED_MODEL}" \
  --dtype "${MERGE_DTYPE}"
