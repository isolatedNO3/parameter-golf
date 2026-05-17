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

if [ -n "${LMMS_EVAL:-}" ]; then
  LMMS_EVAL_CMD=("${LMMS_EVAL}")
elif [ -x ".conda-env/bin/lmms-eval" ]; then
  LMMS_EVAL_CMD=(".conda-env/bin/lmms-eval")
elif command -v lmms-eval >/dev/null 2>&1; then
  LMMS_EVAL_CMD=("lmms-eval")
else
  LMMS_EVAL_CMD=("${PYTHON}" "-m" "lmms_eval")
fi

export CONFIG=${CONFIG:-configs/vlm_textvqa_lora.yaml}
export SEED=${SEED:-1}
export USE_CACHE=${USE_CACHE:-false}
export TASK=${TASK:-textvqa_val}

mapfile -t CFG_VALUES < <("${PYTHON}" - <<'PY'
import os
import yaml

config_path = os.environ["CONFIG"]
with open(config_path, "r", encoding="utf-8") as f:
    cfg = yaml.safe_load(f)
seed = int(os.environ.get("SEED", cfg.get("seed", 1)))
print(cfg["model_path"])
print(os.environ.get("OUTPUT_DIR", cfg["output_dir"]).format(seed=seed))
print(int(cfg["max_pixels"]))
print(int(cfg["min_pixels"]))
PY
)

CFG_MODEL_PATH=${CFG_VALUES[0]}
CFG_OUTPUT_DIR=${CFG_VALUES[1]}
CFG_MAX_PIXELS=${CFG_VALUES[2]}
CFG_MIN_PIXELS=${CFG_VALUES[3]}

if [ -z "${MODEL_PATH:-}" ]; then
  if [ "${USE_BASE_MODEL:-false}" = "true" ]; then
    export MODEL_PATH="${CFG_MODEL_PATH}"
  else
    export MODEL_PATH="${CFG_OUTPUT_DIR}/merged"
  fi
fi

export MAX_PIXELS=${MAX_PIXELS:-${CFG_MAX_PIXELS}}
export MIN_PIXELS=${MIN_PIXELS:-${CFG_MIN_PIXELS}}

echo "[INFO] CONFIG: ${CONFIG}"
echo "[INFO] SEED: ${SEED}"
echo "[INFO] MODEL_PATH: ${MODEL_PATH}"
echo "[INFO] TASK: ${TASK}"
echo "[INFO] MAX_PIXELS: ${MAX_PIXELS}"
echo "[INFO] MIN_PIXELS: ${MIN_PIXELS}"
echo "[INFO] PYTHON: ${PYTHON}"
echo "[INFO] LMMS_EVAL: ${LMMS_EVAL_CMD[*]}"
echo "[INFO] OUTPUT_PATH: ./results/textvqa"

"${PYTHON}" -c "import torch; print('CUDA available:', torch.cuda.is_available()); [print(f'  GPU {i}: {torch.cuda.get_device_name(i)}') for i in range(torch.cuda.device_count())]"

MODEL_ARGS="pretrained=${MODEL_PATH},attn_implementation=eager,device=cuda,max_pixels=${MAX_PIXELS},min_pixels=${MIN_PIXELS},use_cache=${USE_CACHE},device_map=cuda"
echo "[INFO] MODEL_ARGS: ${MODEL_ARGS}"

"${LMMS_EVAL_CMD[@]}" eval \
    --model qwen3_vl \
    --model_args "${MODEL_ARGS}" \
    --tasks "${TASK}" \
    --batch_size 1 \
    --output_path ./results/textvqa
