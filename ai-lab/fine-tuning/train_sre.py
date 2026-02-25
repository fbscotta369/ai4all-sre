import torch
from unsloth import FastLanguageModel
from datasets import load_dataset
from trl import SFTTrainer
from transformers import TrainingArguments

# 1. Configuration - Optimized for RTX 3060 (12GB VRAM)
max_seq_length = 2048 # Supports long post-mortems
load_in_4bit = True    # Critical for 12GB VRAM

# 2. Load Model & Tokenizer
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name = "unsloth/llama-3-8b-bnb-4bit",
    max_seq_length = max_seq_length,
    load_in_4bit = load_in_4bit,
)

# 3. Add LoRA Adapters (The "Fine-Tuning" Layer)
model = FastLanguageModel.get_peft_model(
    model,
    r = 16, # Rank - 16 to 32 is ideal for SRE tasks
    target_modules = ["q_proj", "k_proj", "v_proj", "o_proj",
                      "gate_proj", "up_proj", "down_proj",],
    lora_alpha = 16,
    lora_dropout = 0,
    bias = "none",
    use_gradient_checkpointing = "unsloth", # Saves massive VRAM
    random_state = 3407,
)

# 4. Prompt Template (SRE-Focused)
sre_prompt = """Below is an SRE incident log or post-mortem. Analyze it and provide a technical Root Cause Analysis.

### Incident Data:
{}

### Root Cause Analysis:
{}"""

def formatting_prompts_func(examples):
    inputs       = examples["input"]
    outputs      = examples["output"]
    texts = []
    for input_text, output_text in zip(inputs, outputs):
        text = sre_prompt.format(input_text, output_text)
        texts.append(text)
    return { "text" : texts }

# 5. Load Dataset
dataset = load_dataset("json", data_files="dataset_template.jsonl", split="train")
dataset = dataset.map(formatting_prompts_func, batched = True,)

# 6. Trainer Setup
trainer = SFTTrainer(
    model = model,
    train_dataset = dataset,
    dataset_text_field = "text",
    max_seq_length = max_seq_length,
    args = TrainingArguments(
        per_device_train_batch_size = 2,
        gradient_accumulation_steps = 4,
        warmup_steps = 5,
        max_steps = 60, # Small test run, increase to 500+ for full training
        learning_rate = 2e-4,
        fp16 = not torch.cuda.is_bf16_supported(),
        bf16 = torch.cuda.is_bf16_supported(),
        logging_steps = 1,
        output_dir = "outputs",
    ),
)

# 7. Train!
trainer.train()

# 8. Save the specialized adapter
model.save_pretrained("sre_kernel_adapter")
print("Training Complete. Adapter saved to 'sre_kernel_adapter'")
