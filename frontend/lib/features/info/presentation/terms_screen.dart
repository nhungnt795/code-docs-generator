// lib/features/info/presentation/terms_screen.dart

import 'package:flutter/material.dart';

import '_info_shell.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InfoShell(
      title: 'Điều khoản sử dụng',
      subtitle:
      'Khi sử dụng DocGen VN, bạn đồng ý với các điều khoản dưới đây.',
      icon: Icons.gavel_outlined,
      gradient: const [Color(0xFFF59E0B), Color(0xFFEF4444)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          InfoSection(
            title: '1. Chấp nhận điều khoản',
            children: [
              InfoParagraph(
                'Bằng việc tạo tài khoản hoặc sử dụng bất kỳ tính năng nào của DocGen VN, '
                    'bạn đồng ý với các điều khoản trong tài liệu này. Nếu không đồng ý, '
                    'vui lòng không tiếp tục sử dụng dịch vụ.',
              ),
            ],
          ),
          InfoSection(
            title: '2. Tài khoản người dùng',
            children: [
              InfoBullet(
                  'Bạn phải cung cấp thông tin chính xác khi đăng ký và giữ thông tin luôn được cập nhật.'),
              InfoBullet(
                  'Bạn chịu trách nhiệm bảo mật mật khẩu của tài khoản mình.'),
              InfoBullet(
                  'Một địa chỉ email chỉ được tạo một tài khoản duy nhất.'),
              InfoBullet(
                  'Không sử dụng tài khoản người khác hoặc giả mạo danh tính.'),
            ],
          ),
          InfoSection(
            title: '3. Sử dụng dịch vụ',
            children: [
              InfoParagraph(
                'Bạn được phép sử dụng DocGen VN cho mục đích cá nhân và học tập miễn phí. '
                    'Khi sử dụng, bạn cam kết:',
              ),
              InfoBullet(
                  'Không gửi mã nguồn chứa thông tin nhạy cảm, bí mật thương mại, hoặc tài sản trí tuệ không thuộc về bạn.'),
              InfoBullet(
                  'Không lạm dụng API: gửi quá nhiều yêu cầu, scrape dữ liệu, hoặc tạo nhiều tài khoản ảo.'),
              InfoBullet(
                  'Không cố gắng tấn công, dò lỗ hổng, hoặc phá hoại hệ thống.'),
              InfoBullet(
                  'Không sử dụng dịch vụ cho hoạt động bất hợp pháp.'),
            ],
          ),
          InfoSection(
            title: '4. Quyền sở hữu trí tuệ',
            children: [
              InfoBullet(
                  'Mã nguồn bạn gửi vẫn thuộc quyền sở hữu của bạn. Chúng tôi chỉ xử lý để sinh tài liệu.'),
              InfoBullet(
                  'Tài liệu sinh ra thuộc về bạn - bạn có toàn quyền sử dụng, chỉnh sửa, phát hành.'),
              InfoBullet(
                  'Mã nguồn của ứng dụng DocGen VN (frontend & backend) thuộc về nhóm tác giả.'),
            ],
          ),
          InfoSection(
            title: '5. Giới hạn trách nhiệm',
            children: [
              InfoParagraph(
                'DocGen VN cung cấp dịch vụ "như hiện trạng" (as-is) trong khuôn khổ '
                    'một dự án học thuật. Chúng tôi không đảm bảo tài liệu sinh ra hoàn toàn '
                    'chính xác hoặc phù hợp cho mọi mục đích. Vui lòng kiểm tra lại kết quả '
                    'trước khi sử dụng cho công việc quan trọng.',
              ),
              InfoParagraph(
                'Trong phạm vi pháp luật cho phép, chúng tôi không chịu trách nhiệm cho bất kỳ '
                    'tổn thất gián tiếp, ngẫu nhiên hoặc hậu quả nào phát sinh từ việc sử dụng dịch vụ.',
              ),
            ],
          ),
          InfoSection(
            title: '6. Khóa và chấm dứt tài khoản',
            children: [
              InfoBullet(
                  'Chúng tôi có quyền khóa hoặc xóa tài khoản nếu phát hiện vi phạm điều khoản.'),
              InfoBullet(
                  'Bạn có thể yêu cầu xóa tài khoản bất cứ lúc nào qua email support@docgenvn.id.vn.'),
              InfoBullet(
                  'Dữ liệu sẽ được xóa vĩnh viễn trong vòng 30 ngày sau khi xóa tài khoản.'),
            ],
          ),
          InfoSection(
            title: '7. Sửa đổi điều khoản',
            children: [
              InfoParagraph(
                'Chúng tôi có thể cập nhật điều khoản này theo thời gian. '
                    'Việc bạn tiếp tục sử dụng dịch vụ sau khi điều khoản thay đổi '
                    'được hiểu là bạn đã chấp nhận điều khoản mới.',
              ),
            ],
          ),
          InfoSection(
            title: '8. Luật áp dụng',
            children: [
              InfoParagraph(
                'Các điều khoản này được điều chỉnh bởi pháp luật nước Cộng hòa Xã hội Chủ nghĩa Việt Nam. '
                    'Mọi tranh chấp sẽ được giải quyết tại tòa án có thẩm quyền tại Hà Nội.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}