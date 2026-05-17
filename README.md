# TextVQA Qwen3-VL LoRA + OCR

This repository contains the final TextVQA fine-tuning pipeline based on
`Qwen/Qwen3-VL-2B-Instruct`.  The submitted method is **LoRA fine-tuning with
dataset-provided OCR tokens**.  The OCR tokens are appended to the text prompt
and no extra OCR model is used at inference time, so the evaluation-time model
structure remains the same as the base VLM.

## Final method

- Base model: `Qwen/Qwen3-VL-2B-Instruct`
- Dataset: `lmms-lab/textvqa`
- Adaptation: LoRA
- Extra prompt information: first 8 dataset OCR tokens
- Main config: `configs/vlm_textvqa_lora_ocr8.yaml`
- Training budget: controlled by `max_steps: 768` and `max_train_seconds: 3600`

Important hyperparameters:

```yaml
use_ocr_tokens: true
max_ocr_tokens: 8
max_steps: 768
max_train_seconds: 3600
learning_rate: 0.000015
lora_r: 32
lora_alpha: 64
lora_dropout: 0.03
per_device_train_batch_size: 1
gradient_accumulation_steps: 8
```

The prepared data and output directories include `{seed}` to avoid conflicts:

```yaml
prepared_data_dir: ./data/prepared_textvqa_qwen3vl_ocr8_seed{seed}
output_dir: ./outputs/textvqa_qwen3vl_lora_ocr8_seed{seed}
```

## Environment

The code was tested with:

- Python 3.12.13
- CUDA 12.4
- PyTorch 2.6.0+cu124
- transformers 4.57.0
- accelerate 1.7.0
- peft 0.15.2
- datasets 3.6.0

Install dependencies:

```bash
pip install -r requirements.txt
cd lmms-eval
pip install -e .
cd ..
```

On Windows PowerShell, the scripts first try to use `.\.conda-env\python.exe`
and fall back to `python` if the local environment does not exist.

## Quick start

### Windows PowerShell

Run one seed:

```powershell
cd parameter-golf

.\run_prepare_ocr.ps1 -Seed 1
.\run_train_ocr.ps1 -Seed 1
.\run_merge_lora_ocr.ps1 -Seed 1
.\eval_qwen_ocr.ps1 -Seed 1
```

Run all three seeds:

```powershell
cd parameter-golf

foreach ($s in 1,2,3) {
    .\run_prepare_ocr.ps1 -Seed $s
    .\run_train_ocr.ps1 -Seed $s
    .\run_merge_lora_ocr.ps1 -Seed $s
    .\eval_qwen_ocr.ps1 -Seed $s
}
```

### Linux / Bash

Run one seed:

```bash
cd parameter-golf

SEED=1 bash run_prepare_ocr.sh
SEED=1 bash run_train_ocr.sh
SEED=1 bash run_merge_lora_ocr.sh
SEED=1 bash eval_qwen_ocr.sh
```

Run all three seeds:

```bash
cd parameter-golf

for seed in 1 2 3; do
  SEED=$seed bash run_prepare_ocr.sh
  SEED=$seed bash run_train_ocr.sh
  SEED=$seed bash run_merge_lora_ocr.sh
  SEED=$seed bash eval_qwen_ocr.sh
done
```

## Output paths

For seed `1`, the default paths are:

```text
data/prepared_textvqa_qwen3vl_ocr8_seed1
outputs/textvqa_qwen3vl_lora_ocr8_seed1/final
outputs/textvqa_qwen3vl_lora_ocr8_seed1/merged
results/textvqa/
```

For other seeds, replace `seed1` with `seed2` or `seed3`.

## Evaluation

The OCR evaluation uses the task:

```text
textvqa_val_ocr8
```

The task appends the same OCR prompt format used during training:

```text
Reference OCR token: token1, token2, ...
Answer the question using a single word or phrase.
```

If `MODEL_PATH` was set by a previous command, `eval_qwen_ocr.ps1` clears it by
default and evaluates:

```text
outputs/textvqa_qwen3vl_lora_ocr8_seed{seed}/merged
```

To evaluate a custom merged model:

```powershell
.\eval_qwen_ocr.ps1 -Seed 1 -ModelPath "path\to\merged_model"
```

## Reproduced results

Final LoRA + OCR results on `textvqa_val_ocr8`:

| Seed | exact_match |
|------|-------------|
| 1    | 72.500%     |
| 2    | 72.634%     |
| 3    | 72.808%     |
| Mean | 72.647%     |

Reference results:

| Method | exact_match |
|--------|-------------|
| Base Qwen3-VL-2B-Instruct | 69.886% |
| LoRA baseline, 3-seed mean | 70.969% |
| LoRA + OCR, 3-seed mean | 72.647% |

## Notes 


If Hugging Face networking is unstable, set `model_path` in the config or
   `BASE_MODEL` in the merge script to a local model path.  If the model and
   dataset are already cached, offline mode can be enabled:

```powershell
$env:HF_HUB_OFFLINE="1"
$env:TRANSFORMERS_OFFLINE="1"
```

