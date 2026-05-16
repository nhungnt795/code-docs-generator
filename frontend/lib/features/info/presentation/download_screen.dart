// lib/features/info/presentation/download_screen.dart
// Trang tải xuống ứng dụng DocGen VN cho Android & iOS
// Bao gồm: hướng dẫn tải, hướng dẫn sử dụng, FAQ

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../shared/widgets/dg_misc.dart';
import '_info_shell.dart';

class DownloadScreen extends StatelessWidget {
  const DownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InfoShell(
      title: 'Tải ứng dụng',
      subtitle:
      'DocGen VN có mặt trên cả Android và iOS — sinh tài liệu code mọi lúc, mọi nơi.',
      icon: Icons.download_rounded,
      gradient: const [Color(0xFF4F46E5), Color(0xFF22C55E)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _DownloadSection(),
          SizedBox(height: AppSpacing.s6),
          _InstallGuideSection(),
          SizedBox(height: AppSpacing.s6),
          _UsageGuideSection(),
          SizedBox(height: AppSpacing.s6),
          _FaqSection(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NÚT TẢI
// ─────────────────────────────────────────────────────────────────────────────
class _DownloadSection extends StatelessWidget {
  const _DownloadSection();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return InfoSection(
      title: 'Tải xuống',
      children: [
        Row(
          children: [
            Expanded(
              child: _DownloadCard(
                platform: 'Android',
                icon: Icons.android,
                iconColor: const Color(0xFF3DDC84),
                subtitle: 'APK • Android 8.0+',
                buttonLabel: 'Tải APK',
                // Thay bằng link thật khi build APK
                url: 'https://docgenvn.id.vn/downloads/docgenvn.apk',
                badge: 'v1.0.0',
              ),
            ),
            const SizedBox(width: AppSpacing.s4),
            Expanded(
              child: _DownloadCard(
                platform: 'iOS',
                icon: Icons.apple,
                iconColor: isDark ? Colors.white : Colors.black,
                subtitle: 'TestFlight • iOS 15+',
                buttonLabel: 'Cài qua TestFlight',
                url: 'https://testflight.apple.com/join/docgenvn',
                badge: 'Beta',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: AppColors.infoSoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.info.withOpacity(0.3)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, color: AppColors.info, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ứng dụng iOS hiện trong giai đoạn thử nghiệm qua TestFlight. '
                    'Bản Android có thể cài trực tiếp bằng file APK.',
                style: AppTypography.body
                    .copyWith(color: AppColors.info, fontSize: 14),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _DownloadCard extends StatelessWidget {
  final String platform;
  final IconData icon;
  final Color iconColor;
  final String subtitle;
  final String buttonLabel;
  final String url;
  final String badge;

  const _DownloadCard({
    required this.platform,
    required this.icon,
    required this.iconColor,
    required this.subtitle,
    required this.buttonLabel,
    required this.url,
    required this.badge,
  });

  Future<void> _launch(BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
    } else {
      if (context.mounted) {
        DgToast.show(context, 'Không mở được liên kết: $url', type: ToastType.error);
      }
    }
  }

  void _openUrl(BuildContext context, String url) {
    _launch(context);
  }

  void _launchUrlWeb(String url) {}


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(width: AppSpacing.s3),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(platform,
                  style: AppTypography.h4
                      .copyWith(color: fg, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: AppTypography.caption.copyWith(color: muted)),
            ]),
            const Spacer(),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(badge,
                  style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: AppSpacing.s4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openUrl(context, url),
              icon: const Icon(Icons.download, size: 18),
              label: Text(buttonLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HƯỚNG DẪN CÀI ĐẶT
// ─────────────────────────────────────────────────────────────────────────────
class _InstallGuideSection extends StatelessWidget {
  const _InstallGuideSection();

  @override
  Widget build(BuildContext context) {
    return const InfoSection(
      title: 'Hướng dẫn cài đặt',
      children: [
        _PlatformGuide(
          platform: 'Android',
          icon: Icons.android,
          color: Color(0xFF3DDC84),
          steps: [
            'Tải file APK bằng nút "Tải APK" ở trên.',
            'Mở file APK vừa tải về (thường trong thư mục Downloads).',
            'Nếu có thông báo "Cài từ nguồn không xác định", vào Cài đặt → Bảo mật → bật "Nguồn không xác định".',
            'Nhấn "Cài đặt" và chờ quá trình hoàn tất.',
            'Mở ứng dụng DocGen VN từ màn hình chính.',
          ],
        ),
        SizedBox(height: AppSpacing.s4),
        _PlatformGuide(
          platform: 'iOS (TestFlight)',
          icon: Icons.apple,
          color: Color(0xFF007AFF),
          steps: [
            'Cài đặt ứng dụng TestFlight từ App Store nếu chưa có.',
            'Nhấn nút "Cài qua TestFlight" ở trên.',
            'Trình duyệt sẽ mở TestFlight — nhấn "Chấp nhận" lời mời thử nghiệm.',
            'Nhấn "Cài đặt" trong TestFlight để tải DocGen VN.',
            'Mở ứng dụng sau khi cài đặt xong.',
          ],
        ),
      ],
    );
  }
}

class _PlatformGuide extends StatelessWidget {
  final String platform;
  final IconData icon;
  final Color color;
  final List<String> steps;

  const _PlatformGuide({
    required this.platform,
    required this.icon,
    required this.color,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(platform,
              style: AppTypography.bodyMedium
                  .copyWith(color: fg, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: AppSpacing.s3),
        ...steps.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${e.key + 1}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(e.value,
                  style: AppTypography.body
                      .copyWith(color: muted, height: 1.6)),
            ),
          ]),
        )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HƯỚNG DẪN SỬ DỤNG
// ─────────────────────────────────────────────────────────────────────────────
class _UsageGuideSection extends StatelessWidget {
  const _UsageGuideSection();

  @override
  Widget build(BuildContext context) {
    return const InfoSection(
      title: 'Hướng dẫn sử dụng',
      children: [
        InfoParagraph(
          'Sau khi cài đặt xong, làm theo các bước sau để sinh tài liệu từ mã nguồn của bạn:',
        ),
        _UsageStep(
          number: '1',
          title: 'Đăng ký / Đăng nhập',
          description:
          'Tạo tài khoản mới hoặc đăng nhập bằng email. Kiểm tra hòm thư để xác nhận OTP nếu là tài khoản mới.',
          icon: Icons.person_add_outlined,
        ),
        _UsageStep(
          number: '2',
          title: 'Chọn mô hình AI',
          description:
          'Vào màn hình Sinh tài liệu → chọn mô hình AI phù hợp (Groq nhanh hơn, Kaggle chất lượng hơn).',
          icon: Icons.smart_toy_outlined,
        ),
        _UsageStep(
          number: '3',
          title: 'Dán mã nguồn',
          description:
          'Dán đoạn code cần tài liệu hoá vào ô nhập liệu. Hỗ trợ Python, JavaScript, TypeScript, Java, C++, Dart.',
          icon: Icons.code,
        ),
        _UsageStep(
          number: '4',
          title: 'Chọn ngôn ngữ lập trình',
          description:
          'Chọn đúng ngôn ngữ của đoạn code để hệ thống phân tích AST chính xác hơn.',
          icon: Icons.translate,
        ),
        _UsageStep(
          number: '5',
          title: 'Sinh tài liệu',
          description:
          'Nhấn "Sinh tài liệu". Quá trình mất khoảng 10-30 giây. Kết quả là tài liệu Markdown tiếng Việt.',
          icon: Icons.auto_awesome,
        ),
        _UsageStep(
          number: '6',
          title: 'Xuất tài liệu',
          description:
          'Tải về dạng Markdown (.md), PDF, hoặc Word (.docx) để đưa vào báo cáo, wiki hoặc dự án.',
          icon: Icons.download_outlined,
          isLast: true,
        ),
      ],
    );
  }
}

class _UsageStep extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final IconData icon;
  final bool isLast;

  const _UsageStep({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          if (!isLast)
            Container(
              width: 2,
              height: 24,
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: AppColors.primary.withOpacity(0.2),
            ),
        ]),
        const SizedBox(width: AppSpacing.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(
                  'Bước $number: ',
                  style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600),
                ),
                Text(title,
                    style: AppTypography.bodyMedium.copyWith(
                        color: fg, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 4),
              Text(description,
                  style: AppTypography.body
                      .copyWith(color: muted, height: 1.6)),
              if (!isLast) const SizedBox(height: AppSpacing.s2),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CÂU HỎI THƯỜNG GẶP
// ─────────────────────────────────────────────────────────────────────────────
class _FaqSection extends StatelessWidget {
  const _FaqSection();

  static const _faqs = [
    _Faq(
      q: 'Ứng dụng có miễn phí không?',
      a: 'Có! DocGen VN hoàn toàn miễn phí cho cá nhân. Bạn có thể sinh tài liệu không giới hạn '
          'với mô hình Groq Llama 3.1. Mô hình Finetuned (Kaggle) có thể có giới hạn trong tương lai.',
    ),
    _Faq(
      q: 'Ứng dụng hỗ trợ những ngôn ngữ lập trình nào?',
      a: 'Hiện tại hỗ trợ 6 ngôn ngữ: Python, JavaScript, TypeScript, Java, C++, và Dart. '
          'Chúng tôi đang bổ sung thêm Go, Rust, và C# trong các bản cập nhật tới.',
    ),
    _Faq(
      q: 'Tài liệu sinh ra có chính xác không?',
      a: 'Hệ thống dùng AST (Abstract Syntax Tree) để phân tích cấu trúc code và GraphRAG để '
          'sinh tài liệu, nên kết quả khá chính xác về mặt kỹ thuật. Tuy nhiên, với code phức tạp '
          'hoặc tên biến không rõ ràng, bạn nên kiểm tra lại và chỉnh sửa nếu cần.',
    ),
    _Faq(
      q: 'Code của tôi có được lưu không? Có bảo mật không?',
      a: 'Code và tài liệu chỉ được lưu trong tài khoản của bạn và không chia sẻ ra ngoài. '
          'Chỉ bạn mới có quyền xem lịch sử tài liệu. Chúng tôi không sử dụng code của bạn để huấn luyện mô hình.',
    ),
    _Faq(
      q: 'Tại sao sinh tài liệu mất 10-30 giây?',
      a: 'Hệ thống cần thực hiện nhiều bước: phân tích AST → xây dựng đồ thị tri thức → '
          'gọi mô hình AI → sinh văn bản. Với mô hình Groq (~800 tokens/s), thường chỉ mất 10-15 giây. '
          'Mô hình Kaggle Finetuned có thể mất lâu hơn.',
    ),
    _Faq(
      q: 'Ứng dụng cần kết nối internet không?',
      a: 'Có, ứng dụng cần kết nối internet để gọi API sinh tài liệu. '
          'Kết quả đã sinh sẽ được lưu offline để bạn đọc lại khi không có mạng.',
    ),
    _Faq(
      q: 'Tôi quên mật khẩu, phải làm sao?',
      a: 'Vào màn hình Đăng nhập → nhấn "Quên mật khẩu" → nhập email → '
          'kiểm tra hòm thư lấy mã OTP → đặt lại mật khẩu mới.',
    ),
    _Faq(
      q: 'Làm thế nào để báo lỗi hoặc góp ý?',
      a: 'Bạn có thể liên hệ qua trang Liên hệ, email docgenvn@gmail.com, '
          'hoặc dùng tính năng "Gửi phản hồi" trong ứng dụng (mục Hồ sơ → Phản hồi).',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return InfoSection(
      title: 'Câu hỏi thường gặp',
      children: _faqs.map((faq) => _FaqItem(faq: faq)).toList(),
    );
  }
}

class _Faq {
  final String q;
  final String a;
  const _Faq({required this.q, required this.a});
}

class _FaqItem extends StatefulWidget {
  final _Faq faq;
  const _FaqItem({required this.faq});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _open ? AppColors.primary.withOpacity(0.4) : border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      widget.faq.q,
                      style: AppTypography.bodyMedium.copyWith(
                        color: _open ? AppColors.primary : fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: _open ? AppColors.primary : muted,
                      size: 20,
                    ),
                  ),
                ]),
                if (_open) ...[
                  const SizedBox(height: AppSpacing.s3),
                  Text(
                    widget.faq.a,
                    style: AppTypography.body
                        .copyWith(color: muted, height: 1.65),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}