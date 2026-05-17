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

echo "[INFO] OCR prepare"
echo "[INFO] CONFIG: ${CONFIG}"
echo "[INFO] SEED: ${SEED}"
echo "[INFO] PYTHON: ${PYTHON}"

"${PYTHON}" prepare_textvqa.py --config "${CONFIG}"
