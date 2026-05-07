"""
Training script for fine-tuning Llama 3.1 on Docstring Generation Task.
Environment: Designed for Cloud GPU execution (Kaggle/Colab/AWS) via CLI arguments.
"""

import os
import argparse
import torch
import mlflow
from unsloth import FastLanguageModel
from datasets import load_dataset
from trl import SFTTrainer, SFTConfig
from collections import Counter

def parse_args():
    parser = argparse.ArgumentParser(description="Fine-tune Llama 3.1 with LoRA")
    parser.add_argument("--model_name", type=str, default="unsloth/Meta-Llama-3.1-8B-Instruct", help="Base model path")
    parser.add_argument("--data_path", type=str, required=True, help="Path to train_val_data.jsonl")
    parser.add_argument("--output_dir", type=str, default="./llama3-docstring-lora", help="Output directory for saved model")
    parser.add_argument("--max_seq_length", type=int, default=2048, help="Maximum sequence length")
    parser.add_argument("--epochs", type=int, default=1, help="Number of training epochs")
    return parser.parse_args()

def detect_lang(messages):
    content = messages[0]["content"].lower()
    if "python" in content: return "python"
    if "rust" in content: return "rust"
    if "cpp" in content or "c++" in content: return "cpp"
    if "haskell" in content: return "haskell"
    if "java" in content: return "java"
    if "javascript" in content or "js" in content: return "javascript"
    return "other"

def main():
    args = parse_args()

    # Cảnh báo phần cứng: Tránh việc vô tình chạy trên máy local không có GPU
    if not torch.cuda.is_available():
        print("[!] CẢNH BÁO: Không tìm thấy GPU CUDA. Script này yêu cầu VRAM cao để chạy.")
        print("[!] Vui lòng triển khai script này trên môi trường Cloud (Kaggle/Colab).")
        return

    mlflow.set_experiment("Llama-3.1-Docstring-FineTuning")
    print(f"[*] Bắt đầu quy trình Fine-tuning với model: {args.model_name}")

    # 1. Load Model và Tokenizer
    print("[*] Đang nạp model từ Unsloth...")
    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=args.model_name, 
        max_seq_length=args.max_seq_length, 
        dtype=None, 
        load_in_4bit=True
    )

    # 2. Load và Tiền xử lý dữ liệu
    print(f"[*] Đang đọc dữ liệu từ: {args.data_path}")
    raw_dataset = load_dataset("json", data_files=args.data_path, split="train")

    def process_data(row):
        row["language"] = detect_lang(row["messages"])
        row["text"] = tokenizer.apply_chat_template(
            row["messages"], tokenize=False, add_generation_prompt=False
        )
        return row

    formatted_dataset = raw_dataset.map(process_data, num_proc=2)
    formatted_dataset = formatted_dataset.class_encode_column("language")
    
    # Chia tầng dựa trên cột 'language'
    split_dataset = formatted_dataset.train_test_split(
        test_size=0.1, 
        seed=42, 
        stratify_by_column="language"
    )

    train_data = split_dataset["train"]
    valid_data = split_dataset["test"]

    print(f"[+] Phân bổ ngôn ngữ tập Train: {Counter(train_data['language'])}")
    print(f"[+] Phân bổ ngôn ngữ tập Valid: {Counter(valid_data['language'])}")

    # 3. Cấu hình LoRA
    print("[*] Đang áp dụng cấu hình LoRA (PEFT)...")
    model = FastLanguageModel.get_peft_model(
        model,
        r=16,
        target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
        lora_alpha=16,
        lora_dropout=0,
        bias="none",
        use_gradient_checkpointing="unsloth",
        random_state=42,
    )

    # 4. Khởi tạo Trainer
    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=train_data,
        eval_dataset=valid_data,
        args=SFTConfig(
            dataset_text_field="text",
            max_seq_length=args.max_seq_length, 
            packing=True,                 
            dataset_num_proc=2,
            output_dir=args.output_dir,
            per_device_train_batch_size=2,
            gradient_accumulation_steps=4,
            warmup_steps=10,
            num_train_epochs=args.epochs,
            learning_rate=2e-4,
            fp16=not torch.cuda.is_bf16_supported(),
            bf16=torch.cuda.is_bf16_supported(),
            logging_steps=1,
            eval_strategy="steps",
            eval_steps=50,
            save_strategy="steps",
            save_steps=50,
            optim="adamw_8bit",
            report_to="mlflow"
        ),
    )

    # 5. Bắt đầu huấn luyện
    print("[*] Bắt đầu quá trình huấn luyện...")
    trainer.train()

    # 6. Lưu kết quả
    model.save_pretrained(args.output_dir)
    tokenizer.save_pretrained(args.output_dir)
    print(f"[+] Hoàn tất! Model và weights đã được lưu tại: {args.output_dir}")

if __name__ == "__main__":
    main()