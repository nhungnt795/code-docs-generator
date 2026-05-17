// lib/features/landing/widgets/landing_quick_generate.dart
//
// Widget "Thử ngay" tại Landing — gọi /api/docs/generate/guest.
// Có 6 ngôn ngữ + mã ví dụ + giới hạn 500 ký tự.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/models.dart';
import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../shared/widgets/dg_button.dart';
import '../../../shared/widgets/dg_misc.dart';

const _maxGuestChars = 800;

const Map<ProgrammingLanguage, String> _sampleByLang = {
  ProgrammingLanguage.PYTHON: '''def fibonacci(n):
    """Sinh dãy Fibonacci tới phần tử thứ n."""
    if n <= 1:
        return [0] if n == 1 else []
    seq = [0, 1]
    for _ in range(2, n):
        seq.append(seq[-1] + seq[-2])
    return seq''',

  ProgrammingLanguage.JAVASCRIPT: '''function debounce(fn, delay) {
  let t;
  return (...args) => {
    clearTimeout(t);
    t = setTimeout(() => fn(...args), delay);
  };
}''',

  ProgrammingLanguage.TYPESCRIPT: '''interface User { id: number; name: string; }

async function fetchUser(id: number): Promise<User> {
  const res = await fetch(`/api/users/\${id}`);
  if (!res.ok) throw new Error('Failed');
  return res.json();
}''',

  ProgrammingLanguage.JAVA: '''public class Calculator {
    public int add(int a, int b) { return a + b; }
    public int multiply(int a, int b) { return a * b; }
}''',

  ProgrammingLanguage.CPP: '''#include <vector>

int sum(const std::vector<int>& v) {
    int s = 0;
    for (int x : v) s += x;
    return s;
}''',

  ProgrammingLanguage.RUST: '''fn factorial(n: u64) -> u64 {
    if n <= 1 { 1 } else { n * factorial(n - 1) }
}''',
};

class LandingQuickGenerate extends StatefulWidget {
  const LandingQuickGenerate({super.key});

  @override
  State<LandingQuickGenerate> createState() => _LandingQuickGenerateState();
}

class _LandingQuickGenerateState extends State<LandingQuickGenerate> {
  final _codeCtrl = TextEditingController();
  ProgrammingLanguage _lang = ProgrammingLanguage.PYTHON;
  bool _generating = false;
  String? _output;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _useSample() {
    setState(() {
      _codeCtrl.text = _sampleByLang[_lang] ?? '';
      _output = null;
      _error = null;
    });
  }

  Future<void> _generate({bool ignoreSyntax = false}) async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      DgToast.show(context, 'Vui lòng dán mã nguồn trước',
          type: ToastType.warning);
      return;
    }
    if (code.length > _maxGuestChars) {
      DgToast.show(
        context,
        'Chế độ Khách giới hạn $_maxGuestChars ký tự. Hãy đăng ký để xử lý nội dung lớn hơn.',
        type: ToastType.warning,
      );
      return;
    }

    setState(() {
      _generating = true;
      _output = null;
      _error = null;
    });

    try {
      final res = await ApiClient.instance.post<Map<String, dynamic>>(
        '/api/docs/generate/guest',
        body: {
          'title': 'demo.${_lang.value.toLowerCase()}',
          'source_type': SourceType.DIRECT_TEXT.value,
          'language': _lang.value,
          'raw_code_context': code,
          'ai_model': AIModelType.GROQ_LLAMA3.name,
          'ignore_syntax_warning': ignoreSyntax,
        },
        fromData: (d) => Map<String, dynamic>.from(d as Map),
        timeout: const Duration(minutes: 3),
      );

      if (!mounted) return;

      final doc = res.data?['document'] as Map<String, dynamic>?;
      final warn = res.data?['syntax_warning'] as Map<String, dynamic>?;
      final md = doc?['content_md'] as String?;

      setState(() {
        _generating = false;
        _output = md;
      });

      if (warn != null && (warn['has_error'] == true)) {
        // Hiếm khi xảy ra ở đây vì backend đã trả 422 khi syntax sai và
        // chưa ignore. Nhưng phòng trường hợp backend trả kèm warning + content.
        DgToast.show(
          context,
          warn['message']?.toString() ?? 'Cảnh báo cú pháp',
          type: ToastType.warning,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = e.message;
      });

      // 422 = SYNTAX_WARNING → hỏi người dùng có vẫn muốn tiếp tục
      if (e.statusCode == 422 && e.message.contains('SYNTAX_WARNING')) {
        _showSyntaxWarningDialog(e.message);
      } else {
        DgToast.show(context, e.message, type: ToastType.error);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = e.toString();
      });
      DgToast.show(context, e.toString(), type: ToastType.error);
    }
  }

  void _showSyntaxWarningDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Cảnh báo cú pháp'),
          ],
        ),
        content: Text(
          'Đoạn mã có vẻ chứa lỗi cú pháp ${_lang.displayName}. '
              'Bạn vẫn muốn sinh tài liệu từ mã này chứ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Để tôi sửa lại'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _generate(ignoreSyntax: true);
            },
            child: const Text('Vẫn tiếp tục'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final subtle = isDark ? AppColors.fgSubtleDark : AppColors.fgSubtleLight;

    return Container(
      decoration: BoxDecoration(
        color: card,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMd,
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: chọn ngôn ngữ + nút dùng ví dụ
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bolt,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Thử ngay — không cần đăng ký',
                    style: AppTypography.h4.copyWith(color: fg)),
              ),
              _LangDropdown(
                value: _lang,
                onChanged: (v) => setState(() {
                  _lang = v;
                  _output = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),

          // Code input
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgDark : AppColors.sunkenLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            padding: const EdgeInsets.all(AppSpacing.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Mã nguồn (${_lang.displayName})',
                        style: AppTypography.bodyMedium.copyWith(color: muted)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _useSample,
                      icon:
                      const Icon(Icons.auto_awesome_outlined, size: 14),
                      label: const Text('Dùng ví dụ'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: AppTypography.caption,
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _codeCtrl,
                  maxLines: 10,
                  minLines: 6,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(_maxGuestChars),
                  ],
                  style: AppTypography.code
                      .copyWith(color: fg, fontSize: 12.5),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: _sampleByLang[_lang],
                    hintStyle: AppTypography.code
                        .copyWith(color: subtle, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.s4),

          // Action row
          LayoutBuilder(builder: (ctx, c) {
            final isNarrow = c.maxWidth < 460;
            final btn = DgButton.primary(
              label: _generating
                  ? 'Đang sinh tài liệu...'
                  : 'Sinh tài liệu ngay',
              icon: Icons.auto_awesome,
              loading: _generating,
              fullWidth: isNarrow,
              onPressed: _generating ? null : () => _generate(),
            );
            final hint = Text(
              'Giới hạn $_maxGuestChars ký tự cho chế độ Khách',
              style: AppTypography.caption.copyWith(color: subtle),
            );
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [btn, const SizedBox(height: 8), Center(child: hint)],
              );
            }
            return Row(
              children: [btn, const SizedBox(width: 14), Flexible(child: hint)],
            );
          }),

          // Output
          if (_output != null) ...[
            const SizedBox(height: AppSpacing.s5),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                const Icon(Icons.description_outlined,
                    color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Text('Tài liệu sinh ra',
                    style: AppTypography.bodyMedium.copyWith(color: fg)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _output!));
                    DgToast.show(context, 'Đã copy Markdown',
                        type: ToastType.success);
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copy'),
                  style: TextButton.styleFrom(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 360),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
              decoration: BoxDecoration(
                color: isDark ? AppColors.bgDark : AppColors.sunkenLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border),
              ),
              child: SingleChildScrollView(
                child: MarkdownBody(
                  data: _output!,
                  selectable: true,
                  styleSheet:
                  MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: AppTypography.body.copyWith(color: fg),
                    code: AppTypography.codeSm.copyWith(
                      backgroundColor:
                      isDark ? AppColors.cardDark : Colors.white,
                      color: fg,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                Expanded(
                  child: DgButton.secondary(
                    label: 'Đăng ký để lưu lịch sử',
                    icon: Icons.bookmark_add_outlined,
                    onPressed: () => context.push('/login/register'),
                  ),
                ),
              ],
            ),
          ] else if (_error != null && !_error!.contains('SYNTAX_WARNING')) ...[
            const SizedBox(height: AppSpacing.s4),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LangDropdown extends StatelessWidget {
  final ProgrammingLanguage value;
  final ValueChanged<ProgrammingLanguage> onChanged;
  const _LangDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProgrammingLanguage>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          style: AppTypography.bodySmall.copyWith(color: fg),
          items: ProgrammingLanguage.values
              .map((l) => DropdownMenuItem(
            value: l,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(l.icon, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(l.displayName),
              ],
            ),
          ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}