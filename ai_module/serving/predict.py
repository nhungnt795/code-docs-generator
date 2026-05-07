import json
import torch
from tqdm import tqdm
from unsloth import FastLanguageModel

MODEL_PATH = "ai_module\weights\llama3-docstring-lora"
TEST_FILE = "data/processed/test_data.jsonl"            
OUTPUT_FILE = "model/serving/predictions.jsonl"    

def main():
    print("[*] Đang khởi động Llama 3.1...")
    
    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=MODEL_PATH,
        max_seq_length=2048,
        dtype=None,         
        load_in_4bit=True,   
    )
    
    FastLanguageModel.for_inference(model)
    
    print(f"[*] Đã load model thành công. Đang đọc file test: {TEST_FILE}")
    
    with open(TEST_FILE, 'r', encoding='utf-8') as f:
        test_data = [json.loads(line) for line in f]
        
    print(f"[*] Tổng số mẫu cần dự đoán: {len(test_data)}")
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as out_f:
        
        for data in tqdm(test_data, desc="Đang sinh Docstring"):
            original_messages = data["messages"]
            
            prompt_messages = [msg for msg in original_messages if msg["role"] in ["system", "user"]]
            
            inputs = tokenizer.apply_chat_template(
                prompt_messages,
                tokenize=True,
                add_generation_prompt=True,
                return_tensors="pt"
            ).to("cuda")
            
            prompt_length = inputs.shape[1]
            
            with torch.no_grad():
                outputs = model.generate(
                    input_ids=inputs,
                    max_new_tokens=512, 
                    temperature=0.2,    
                    top_p=0.9,
                    do_sample=True,
                    pad_token_id=tokenizer.eos_token_id
                )
            
            generated_tokens = outputs[0][prompt_length:]
            predicted_text = tokenizer.decode(generated_tokens, skip_special_tokens=True).strip()
            
            result_obj = {
                "predicted_docstring": predicted_text,
                "original_messages": original_messages 
            }
            
            out_f.write(json.dumps(result_obj, ensure_ascii=False) + '\n')
            
    print(f"\n[+] HOÀN TẤT! Đã lưu kết quả ra file: {OUTPUT_FILE}")

if __name__ == "__main__":
    main()