from transformers import AutoTokenizer, AutoModel
import torch

class CodeBERTEmbedder:
    def __init__(self, model_name="microsoft/codebert-base"):
        print("[*] Đang nạp CodeBERT Embedder...")
        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
        self.model = AutoModel.from_pretrained(model_name)
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.model.to(self.device)

    def get_embedding(self, text):
        inputs = self.tokenizer(text, return_tensors="pt", truncation=True, max_length=512).to(self.device)
        with torch.no_grad():
            outputs = self.model(**inputs)
        # Ép về dạng list phẳng 1 chiều để psycopg2 không bị lỗi
        embedding = outputs.last_hidden_state[0, 0, :].cpu().numpy().tolist()
        return embedding
