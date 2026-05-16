# Ma trận Quản lý Ngoại lệ Hệ thống (Exception Handling Matrix)

**Dự án:** VietDocGen - Phân hệ Sinh tài liệu AI  

| Mã HTTP | Mã Lỗi Nội Bộ | Nguyên nhân Cốt lõi (Root Cause) | Thông điệp trả về cho Client (Frontend) | Cơ chế Xử lý & Dự phòng (System Action & Fallback) |
| :--- | :--- | :--- | :--- | :--- |
| **400** | `ERR_BAD_PAYLOAD` | Dữ liệu không hợp lệ: Code rỗng, sai JSON, hoặc ngôn ngữ không hỗ trợ. | "Dữ liệu yêu cầu không hợp lệ. Vui lòng kiểm tra lại mã nguồn." | Hủy request tại API Gateway. Không gọi LLM Engine để bảo vệ tài nguyên GPU. |
| **503** | `ERR_DB_TIMEOUT` | Mất kết nối đến Vector Database (PGVector downtime). | "Hệ thống truy xuất dữ liệu gián đoạn. Đang sinh tài liệu ở chế độ cơ bản..." | **Graceful Degradation:** Bỏ qua RAG, gửi trực tiếp code cho LLaMA xử lý độc lập. |
| **504** | `ERR_LLM_TIMEOUT` | LLM Engine phản hồi chậm (> 60s) do code quá dài hoặc server tải cao. | "Mô hình AI đang xử lý lượng dữ liệu lớn. Vui lòng thử lại sau." | Hệ thống tự động **Retry** tối đa 2 lần. Nếu vẫn lỗi, ngắt kết nối để tránh treo luồng. |
| **429** | `ERR_RATE_LIMIT` | Lưu lượng truy cập vượt ngưỡng (Spam API liên tục). | "Bạn đã gửi quá nhiều yêu cầu. Vui lòng thử lại sau 60 giây." | Kích hoạt **Throttling**. Tạm thời chặn IP nguồn trong vòng 1 phút. |