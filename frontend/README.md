# DocGen VN — Frontend

Giao diện người dùng của hệ thống tự động sinh tài liệu mã nguồn Tiếng Việt, xây dựng bằng **Flutter** hỗ trợ đa nền tảng: Web, Android, iOS.

---

## Yêu cầu hệ thống

- Flutter SDK 3.22.0+
- Dart SDK 3.3.0+
- Android Studio / VS Code
- Chrome (để debug web)
- Android SDK (để debug Android)

---

## Cấu trúc thư mục

```
frontend/
├── lib/
│   ├── main_user.dart            # Entry point app người dùng
│   ├── main_admin.dart           # Entry point app quản trị
│   ├── app_user.dart             # MaterialApp + theme người dùng
│   ├── app_admin.dart            # MaterialApp + theme admin
│   ├── core/
│   │   ├── api/
│   │   │   ├── api_client.dart   # HTTP client, xử lý lỗi, parse response
│   │   │   ├── api_config.dart   # Base URL, timeout
│   │   │   └── models.dart       # Data models (User, Document, ...)
│   │   ├── auth/
│   │   │   └── auth_provider.dart  # Riverpod: trạng thái đăng nhập
│   │   ├── router/
│   │   │   ├── user_router.dart    # GoRouter người dùng
│   │   │   └── admin_router.dart   # GoRouter admin
│   │   ├── theme/
│   │   └── tokens/               # AppColors, AppTypography, AppSpacing
│   ├── features/
│   │   ├── auth/                 # Đăng nhập, đăng ký, OTP, reset password
│   │   ├── generate/             # Sinh tài liệu, chọn model AI, kiểm tra syntax
│   │   ├── history/              # Lịch sử tài liệu
│   │   ├── profile/              # Thông tin cá nhân, đổi mật khẩu, avatar
│   │   ├── admin/                # Dashboard, quản lý user & model AI
│   │   ├── landing/              # Trang chủ, splash screen
│   │   └── info/                 # About, contact, download, terms, privacy
│   └── shared/
│       ├── layout/               # AppScaffold, Topbar, Sidebar
│       └── widgets/              # DgToast, các widget dùng chung
├── assets/
│   ├── fonts/                    # Inter, JetBrainsMono
│   └── icons/
└── pubspec.yaml
```

---

## Cài đặt & Chạy

```bash
# 1. Cài dependencies
flutter pub get

# 2. Chạy app người dùng trên Chrome (port cố định để tránh lỗi CORS)
flutter run -t lib/main_user.dart -d chrome --web-port=8080

# 3. Chạy app admin trên Chrome
flutter run -t lib/main_admin.dart -d chrome --web-port=8081

# 4. Chạy trên Android (cắm USB hoặc mở emulator trước)
flutter run -t lib/main_user.dart -d android
```

> **Quan trọng:** Luôn dùng `--web-port=8080` khi debug web để tránh lỗi CORS với backend. Port random mỗi lần chạy sẽ bị backend chặn.

---

## Cấu hình URL Backend

File `lib/core/api/api_config.dart`:

```dart
static String get baseUrl {
  return 'https://docgenvn.id.vn'; // Production
  // Đổi thành 'http://localhost:8000' nếu chạy backend local
}
```

---

## Build & Deploy lên AWS

### Bước 1 — Build Web

```bash
# Build app người dùng
flutter build web --release -t lib/main_user.dart

# Nén output
cd build/web
zip -r ../../docgen_web.zip .
```

### Bước 2 — Upload lên server (WinSCP)

Copy file `docgen_web.zip` vào server, ví dụ `/home/ubuntu/`.

### Bước 3 — Giải nén & Kích hoạt Nginx

```bash
# SSH vào server
ssh ubuntu@<your-ip>

# Giải nén vào thư mục web
sudo unzip -o ~/docgen_web.zip -d /var/www/html/

# Reload Nginx
sudo nginx -t && sudo systemctl reload nginx
```

---

## Packages chính

| Package | Mục đích |
|---------|----------|
| `go_router ^14.0.0` | Navigation, deep linking |
| `flutter_riverpod ^2.5.1` | State management |
| `shared_preferences ^2.3.0` | Lưu token, theme |
| `http ^1.2.2` | Gọi REST API |
| `file_picker ^8.1.2` | Chọn file mã nguồn |
| `image_picker ^1.2.2` | Chọn ảnh đại diện |
| `flutter_markdown ^0.7.3` | Render tài liệu sinh ra |
| `fl_chart ^0.68.0` | Biểu đồ dashboard admin |
| `shimmer ^3.0.0` | Skeleton loading |

---

## Tính năng

**Người dùng**
- Đăng ký / đăng nhập / xác thực OTP email / reset mật khẩu
- Nhập mã nguồn hoặc upload file, chọn ngôn ngữ lập trình
- Kiểm tra syntax trước khi sinh — cảnh báo lỗi, cho phép bỏ qua
- Chọn mô hình AI (Groq Cloud / Kaggle Finetuned)
- Xem, sửa, xuất tài liệu dạng MD / PDF / DOCX
- Lịch sử tài liệu đã sinh
- Cập nhật thông tin cá nhân, ảnh đại diện

**Quản trị viên**
- Dashboard thống kê (tài liệu, người dùng, ngôn ngữ phổ biến)
- Quản lý tài khoản người dùng (khoá, mở khoá)
- Bật / tắt mô hình AI
- Xem feedback từ người dùng

---

## Lưu ý khi phát triển

**CORS khi debug local:** Backend chỉ chấp nhận các origin được liệt kê trong `main.py`. Luôn dùng port cố định:
```bash
flutter run -d chrome --web-port=8080
```

**Hot reload vs Hot restart:** Dùng `r` để hot reload (giữ state), `R` để hot restart (reset toàn bộ) trong terminal khi debug.

**Đổi môi trường:** Để trỏ về backend local thay vì server AWS, sửa `baseUrl` trong `api_config.dart` rồi hot restart.
