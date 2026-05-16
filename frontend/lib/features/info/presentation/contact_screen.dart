// lib/features/info/presentation/contact_screen.dart
// Trang Liên hệ - yêu cầu I.14

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_client.dart';
import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../shared/widgets/dg_button.dart';
import '../../../shared/widgets/dg_input.dart';
import '../../../shared/widgets/dg_misc.dart';
import '_info_shell.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_emailCtrl.text.trim().isEmpty || _msgCtrl.text.trim().isEmpty) {
      DgToast.show(context, 'Vui lòng nhập email và nội dung',
          type: ToastType.warning);
      return;
    }
    setState(() => _sending = true);
    try {
      final res = await ApiClient.instance.post<Map<String, dynamic>>(
        '/api/contact',
        body: {
          'name': _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'content': _msgCtrl.text.trim(),
        },
        fromData: (d) => Map<String, dynamic>.from(d as Map),
      );

      if (!mounted) return;

      setState(() {
        _sending = false;
        _nameCtrl.clear();
        _emailCtrl.clear();
        _msgCtrl.clear();
      });
      DgToast.show(
        context,
        res.message ??
            'Cảm ơn bạn đã liên hệ! Chúng tôi sẽ phản hồi qua email sớm nhất.',
        type: ToastType.success,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      DgToast.show(context, e.message, type: ToastType.error);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      DgToast.show(
        context,
        'Không thể kết nối máy chủ. Vui lòng thử lại sau.',
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InfoShell(
      title: 'Liên hệ với chúng tôi',
      subtitle:
      'Có thắc mắc, góp ý hoặc cần hỗ trợ? Đội ngũ DocGen VN luôn sẵn sàng lắng nghe.',
      icon: Icons.mail_outline,
      gradient: const [Color(0xFF22C55E), Color(0xFF4F46E5)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thông tin liên hệ
          const InfoSection(
            title: 'Thông tin liên hệ',
            children: [
              _ContactItem(
                icon: Icons.mail_outline,
                label: 'Email',
                value: 'docgenvn@gmail.com',
                copyable: true,
              ),
              _ContactItem(
                icon: Icons.public,
                label: 'Website',
                value: 'https://docgenvn.id.vn',
              ),
              _ContactItem(
                icon: Icons.location_on_outlined,
                label: 'Địa chỉ',
                value:
                'Trường Đại học Khoa học Tự nhiên, ĐHQGHN\n334 Nguyễn Trãi, Thanh Xuân, Hà Nội',
              ),
              _ContactItem(
                icon: Icons.access_time,
                label: 'Giờ làm việc',
                value: 'Thứ Hai - Thứ Sáu, 8:00 - 17:30',
              ),
            ],
          ),

          // Form gửi tin
          InfoSection(
            title: 'Gửi tin nhắn',
            children: [
              const InfoParagraph(
                'Điền form bên dưới và chúng tôi sẽ phản hồi qua email của bạn.',
              ),
              const SizedBox(height: 8),
              DgInput(
                label: 'Họ và tên',
                hint: 'Nguyễn Văn A',
                controller: _nameCtrl,
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: AppSpacing.s4),
              DgInput(
                label: 'Email',
                hint: 'email@example.com',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline,
              ),
              const SizedBox(height: AppSpacing.s4),
              DgInput(
                label: 'Nội dung',
                hint: 'Mô tả vấn đề / góp ý / câu hỏi của bạn',
                controller: _msgCtrl,
                maxLines: 5,
              ),
              const SizedBox(height: AppSpacing.s5),
              DgButton.primary(
                label: _sending ? 'Đang gửi...' : 'Gửi tin nhắn',
                icon: Icons.send,
                loading: _sending,
                onPressed: _sending ? null : _send,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool copyable;
  const _ContactItem({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.caption.copyWith(color: muted)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(value,
                          style: AppTypography.body.copyWith(color: fg)),
                    ),
                    if (copyable) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: value));
                          DgToast.show(context, 'Đã copy',
                              type: ToastType.success);
                        },
                        child: const Icon(Icons.copy,
                            size: 14, color: AppColors.primary),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}