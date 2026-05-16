# Danh sách Kiểm tra Nghiệm thu Người dùng (UAT Checklist)

**Dự án:** VietDocGen  
**Người phụ trách:** Nguyễn Tố Uyên (23001952)

## 1. Kiểm tra Chức năng (Functional Testing)
- [ ] Nhận diện và xử lý chính xác 6 ngôn ngữ: Python, C++, Java, JS, TS, Rust.
- [ ] Trích xuất đúng tên hàm/phương thức từ mã nguồn đưa vào.
- [ ] Tài liệu Markdown sinh ra đúng cấu trúc: Mô tả, Tham số, Giá trị trả về.
- [ ] Không chứa Emoji/Icon trong nội dung tài liệu (Tuân thủ System Prompt).

## 2. Kiểm tra Chất lượng AI (QC Monitoring)
- [ ] Điểm BLEU trung bình trên tập Test đạt trên 25.0.
- [ ] Điểm ROUGE-L trung bình đạt trên 40.0.
- [ ] Điểm CodeBERTScore F1 (Ngữ nghĩa) đạt trên 70.0.

## 3. Kiểm tra Độ ổn định (Reliability)
- [ ] Trả về mã lỗi `ERR_BAD_PAYLOAD` khi gửi code rỗng.
- [ ] Tự động chuyển sang chế độ "Sinh tài liệu cơ bản" khi PGVector mất kết nối.
- [ ] Thời gian phản hồi trung bình cho một hàm thông thường < 15 giây.

## 4. Giám sát Yêu cầu Phi chức năng (Non-functional Monitoring)

### 4.1. Chỉ số Bảo mật (Security Auditing)
- [ ] **Data Sanitization (Làm sạch dữ liệu đầu vào):** Các input nhận từ user (đặc biệt là `repo_url` hoặc `raw_code`) phải đi qua cơ chế lọc (Regex/Validator). Chống tuyệt đối khai thác Command Injection khi Server thực thi các lệnh như `git clone`.
- [ ] **Secret Management (Quản lý biến nhạy cảm):** Mật khẩu DB PostgreSQL, Token HuggingFace/Kaggle, và API Keys TUYỆT ĐỐI chỉ lưu trong biến môi trường (`.env`).
- [ ] **Git Pre-commit Check:** Kiểm tra kỹ file `.gitignore` để đảm bảo không rò rỉ file `.env` hoặc file `predictions.jsonl` (chứa dữ liệu nhạy cảm của hệ thống) khi push code lên repository chung.

### 4.2. Chỉ số Hiệu năng & Tối ưu hóa (Performance Benchmarks)
- [ ] **Database Optimization (Tối ưu truy xuất):** Bảng vector lưu trữ AST/Code Snippets trong PGVector phải sử dụng Index định dạng **HNSW (Hierarchical Navigable Small World)** để đảm bảo tốc độ truy vấn Cosine Similarity luôn đạt mức `< 200ms`.
- [ ] **Context Window Efficiency (Tối ưu ngữ cảnh AI):** Tích hợp bước tiền xử lý (Preprocessing): Lọc bỏ comments không cần thiết và các dòng trống (blank lines) của mã nguồn thô trước khi đưa vào LLaMA. Điều này giúp tối ưu hóa bộ nhớ RAM, tiết kiệm VRAM của GPU và giảm thiểu thời gian chờ (Latency) khi sinh text.