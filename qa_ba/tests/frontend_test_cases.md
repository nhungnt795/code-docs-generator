# Kiểm thử Chất lượng Giao diện (Frontend QA)
**Dự án:** VietDocGen (Hệ thống sinh tài liệu mã nguồn)
**Người phụ trách QA/QC:** Nguyễn Tố Uyên

### 1. Kiểm thử Hiển thị (Rendering - Dành cho Flutter)
- [ ] **Render Markdown:** Giao diện không bị vỡ layout khi LLaMA trả về bảng (Table) Markdown chứa nội dung dài.
- [ ] **Render Code Block:** Các đoạn mã nguồn có thanh cuộn ngang (horizontal scroll), highlight đúng cú pháp (Syntax highlighting), không tràn màn hình.
- [ ] **Responsive:** Các nút bấm, khung nhập URL không bị che khuất trên màn hình Mobile/Tablet.

### 2. Kiểm thử Trạng thái (State Management)
- [ ] **Loading State:** Khi chờ API xử lý, màn hình có hiệu ứng Shimmer/Spinner rõ ràng và **vô hiệu hóa (disable)** nút "Sinh tài liệu" để tránh spam request.
- [ ] **Timeout Handling:** Nếu quá 60s không có phản hồi từ Backend, tự động ngắt và hiển thị lỗi Timeout thân thiện.
- [ ] **Empty State:** Hiển thị hướng dẫn sử dụng ở màn hình chính khi chưa có dữ liệu.

### 3. Kiểm thử Xử lý Lỗi (Error UI)
- [ ] **Input Validation:** Nút "Sinh tài liệu" bị mờ nếu link Github sai định dạng (không chứa github.com).
- [ ] **Error Toast:** Bắt các mã lỗi HTTP 400, 500 từ Backend và hiển thị Snackbar/Toast thông báo rõ ràng cho người dùng.