// lib/features/info/presentation/privacy_screen.dart

import 'package:flutter/material.dart';

import '_info_shell.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InfoShell(
      title: 'Chính sách bảo mật',
      subtitle:
      'DocGen VN cam kết bảo vệ thông tin cá nhân và dữ liệu mã nguồn của người dùng.',
      icon: Icons.shield_outlined,
      gradient: const [Color(0xFF3B82F6), Color(0xFF4F46E5)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InfoSection(
            title: '1. Thông tin chúng tôi thu thập',
            children: [
              InfoParagraph(
                'Khi bạn sử dụng DocGen VN, chúng tôi có thể thu thập các loại thông tin sau:',
              ),
              InfoBullet(
                  'Thông tin tài khoản: email, họ tên, ảnh đại diện (do bạn cung cấp).'),
              InfoBullet(
                  'Mã nguồn bạn gửi để sinh tài liệu - được lưu vào tài khoản của bạn.'),
              InfoBullet(
                  'Nhật ký hoạt động: thời gian đăng nhập, các hành động chính (sinh, sửa, xuất tài liệu).'),
              InfoBullet(
                  'Thông tin kỹ thuật: địa chỉ IP, loại thiết bị, trình duyệt - phục vụ bảo mật.'),
            ],
          ),
          const InfoSection(
            title: '2. Cách chúng tôi sử dụng thông tin',
            children: [
              InfoBullet('Cung cấp và duy trì dịch vụ sinh tài liệu.'),
              InfoBullet(
                  'Lưu trữ lịch sử tài liệu để bạn có thể xem lại, chỉnh sửa.'),
              InfoBullet('Phát hiện và ngăn chặn hành vi lạm dụng hoặc gian lận.'),
              InfoBullet(
                  'Cải thiện chất lượng mô hình AI thông qua dữ liệu ẩn danh, không gắn với cá nhân.'),
            ],
          ),
          const InfoSection(
            title: '3. Chia sẻ thông tin với bên thứ ba',
            children: [
              InfoParagraph(
                'Chúng tôi KHÔNG bán, KHÔNG cho thuê dữ liệu cá nhân của bạn. '
                    'Mã nguồn bạn gửi chỉ được xử lý trong phạm vi hệ thống DocGen VN '
                    'và các nhà cung cấp dịch vụ AI (như Groq) để sinh tài liệu.',
              ),
              InfoParagraph(
                'Chúng tôi chỉ chia sẻ thông tin khi pháp luật yêu cầu, '
                    'hoặc khi cần thiết để bảo vệ quyền lợi hợp pháp của DocGen VN '
                    'và người dùng.',
              ),
            ],
          ),
          const InfoSection(
            title: '4. Quyền của bạn',
            children: [
              InfoBullet(
                  'Truy cập và chỉnh sửa thông tin cá nhân trong trang Hồ sơ.'),
              InfoBullet(
                  'Xóa tài liệu lịch sử bất kỳ lúc nào.'),
              InfoBullet(
                  'Yêu cầu xóa hoàn toàn tài khoản - liên hệ support@docgenvn.id.vn.'),
              InfoBullet(
                  'Xuất dữ liệu cá nhân theo định dạng máy đọc được.'),
            ],
          ),
          const InfoSection(
            title: '5. Bảo mật dữ liệu',
            children: [
              InfoBullet(
                  'Mật khẩu được mã hóa bằng thuật toán bcrypt - chúng tôi không lưu mật khẩu gốc.'),
              InfoBullet(
                  'Kết nối được mã hóa qua HTTPS/TLS với Cloudflare CDN.'),
              InfoBullet(
                  'Cơ sở dữ liệu chạy trong môi trường cô lập (Docker container, AWS EC2).'),
              InfoBullet(
                  'Sao lưu định kỳ và kiểm soát truy cập bằng vai trò (User/Admin).'),
            ],
          ),
          const InfoSection(
            title: '6. Cookie',
            children: [
              InfoParagraph(
                'Trang web sử dụng cookie cần thiết để duy trì phiên đăng nhập '
                    'và lưu tùy chọn giao diện (sáng/tối). Chúng tôi không sử dụng '
                    'cookie tracking quảng cáo của bên thứ ba.',
              ),
            ],
          ),
          const InfoSection(
            title: '7. Thay đổi chính sách',
            children: [
              InfoParagraph(
                'Chính sách này có thể được cập nhật theo thời gian. Mọi thay đổi quan trọng '
                    'sẽ được thông báo qua email hoặc thông báo trong ứng dụng. '
                    'Phiên bản cập nhật lần cuối: tháng 5/2026.',
              ),
            ],
          ),
          const InfoSection(
            title: '8. Liên hệ',
            children: [
              InfoParagraph(
                'Mọi câu hỏi về chính sách bảo mật, vui lòng gửi email tới '
                    'docgenvn@gmail.com hoặc qua trang Liên hệ.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}