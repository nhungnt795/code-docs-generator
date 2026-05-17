// lib/features/landing/presentation/landing_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/dg_button.dart';
import '../../../shared/widgets/dg_misc.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _codeCtrl   = TextEditingController();
  bool  _generating = false;
  String? _output;

  // Dùng cho Mobile PageView
  late final PageController _pageCtrl;
  int _currentPage = 0;

  final _sampleCode = '''// Dán mã nguồn của bạn vào đây
function calculateSum(a, b) {
  return a + b;
}

class UserService {
  async getUser(id) {
    return await db.users.findById(id);
  }
}''';

  @override
  void initState() {
    super.initState();
    // viewportFraction: 0.95 giúp hiển thị lấp ló một phần thẻ tiếp theo
    _pageCtrl = PageController(viewportFraction: 0.95);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _quickGenerate() async {
    if (_codeCtrl.text.trim().isEmpty) {
      DgToast.show(context, 'Vui lòng dán mã nguồn trước', type: ToastType.warning);
      return;
    }
    setState(() => _generating = true);
    await Future.delayed(const Duration(milliseconds: 1800));
    // TODO: gọi API /docs/generate với code snippet (giới hạn 500 ký tự cho guest)
    if (!mounted) return;
    setState(() {
      _generating = false;
      _output = '''## calculateSum

**Mô tả:** Hàm tính tổng hai số.

**Tham số:**
- `a` — Số thứ nhất
- `b` — Số thứ hai

**Trả về:** Tổng của `a` và `b`.

---

## UserService

**Mô tả:** Service xử lý nghiệp vụ người dùng.

### getUser(id)
Lấy thông tin người dùng theo ID từ cơ sở dữ liệu.

**Tham số:** `id` — ID của người dùng
**Trả về:** `Promise<User>`''';
    });
  }

  @override
  Widget build(BuildContext context) {
    // Phân luồng giao diện: Nếu là Mobile thì hiển thị thẻ vuốt ngang, ngược lại hiển thị cuộn dọc
    if (Responsive.isMobile(context)) {
      return _buildMobileView(context);
    }
    return _buildDesktopView(context);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1. MOBILE VIEW (DẠNG THẺ VUỐT NGANG - ONBOARDING)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildMobileView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AppColors.bgDark   : AppColors.bgLight;
    final fg     = isDark ? AppColors.fgDark   : AppColors.fgLight;
    final card   = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final muted  = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final subtle = isDark ? AppColors.fgSubtleDark : AppColors.fgSubtleLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.code, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'Inter', fontSize: 16,
                  fontWeight: FontWeight.w700, color: fg,
                ),
                children: const [
                  TextSpan(text: 'DocGen'),
                  TextSpan(
                    text: ' VN',
                    style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/login'),
            child: Text(
              'Đăng nhập',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: [
                // Thẻ 1: Hero Intro
                _buildMobileCard(
                  context,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Text(
                          'Tự động hoá tài liệu',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary, fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s5),
                      Text(
                        'Sinh tài liệu Tiếng Việt\ntừ mã nguồn của bạn',
                        style: AppTypography.h2.copyWith(color: fg, height: 1.3),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'Phân tích codebase và tạo tài liệu có cấu trúc, dễ đọc bằng Tiếng Việt. Hỗ trợ hơn 20 ngôn ngữ lập trình phổ biến.',
                        style: AppTypography.body.copyWith(color: muted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      DgButton.primary(
                        label: 'Bắt đầu miễn phí',
                        fullWidth: true,
                        icon: Icons.arrow_forward,
                        onPressed: () => context.push('/login/register'),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      DgButton.secondary(
                        label: 'Vuốt để xem tính năng',
                        fullWidth: true,
                        icon: Icons.swipe_left,
                        onPressed: () => _pageCtrl.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                      ),
                    ],
                  ),
                ),

                // Thẻ 2: Features
                _buildMobileCard(
                  context,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Tính năng chính',
                        style: AppTypography.h2.copyWith(color: fg),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      ..._features(isDark, fg, muted).map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                        child: f,
                      )),
                    ],
                  ),
                ),

                // Thẻ 3: Quick Try
                _buildMobileCard(
                  context,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thử ngay',
                          style: AppTypography.h2.copyWith(color: fg),
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        Text(
                          'Dán tối đa 500 ký tự mã nguồn.',
                          style: AppTypography.body.copyWith(color: muted),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Mã nguồn',
                              style: AppTypography.bodyMedium.copyWith(color: fg),
                            ),
                            TextButton.icon(
                              onPressed: () => setState(() => _codeCtrl.text = _sampleCode),
                              icon: const Icon(Icons.auto_awesome_outlined, size: 14),
                              label: const Text('Dùng ví dụ'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                textStyle: AppTypography.caption,
                                foregroundColor: AppColors.primary,
                                minimumSize: Size.zero,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.bgDark : AppColors.sunkenLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: border),
                          ),
                          padding: const EdgeInsets.all(AppSpacing.s3),
                          child: TextField(
                            controller: _codeCtrl,
                            maxLines: 6,
                            style: AppTypography.code.copyWith(
                              color: fg, fontSize: 12,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: _sampleCode,
                              hintStyle: AppTypography.code.copyWith(
                                color: subtle, fontSize: 12,
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        DgButton.primary(
                          label: _generating ? 'Đang sinh tài liệu...' : 'Sinh tài liệu',
                          fullWidth: true,
                          icon: Icons.bolt,
                          loading: _generating,
                          onPressed: _generating ? null : _quickGenerate,
                        ),
                        if (_output != null) ...[
                          const SizedBox(height: AppSpacing.s4),
                          const Divider(),
                          const SizedBox(height: AppSpacing.s3),
                          Text(
                            'Kết quả',
                            style: AppTypography.bodyMedium.copyWith(color: fg),
                          ),
                          const SizedBox(height: AppSpacing.s2),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.s4),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.bgDark : AppColors.sunkenLight,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: border),
                            ),
                            child: Text(
                              _output!,
                              style: AppTypography.body.copyWith(color: fg),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Row of Dot Indicators
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? AppColors.primary : border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
        ],
      ),
    );
  }

  Widget _buildMobileCard(BuildContext context, {required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card   = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.s4, bottom: AppSpacing.s2, left: 6, right: 6),
      padding: const EdgeInsets.all(AppSpacing.s6),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2. DESKTOP / WEB VIEW (DẠNG CUỘN DỌC - NHƯ CŨ)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AppColors.bgDark   : AppColors.bgLight;
    final card   = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final fg     = isDark ? AppColors.fgDark   : AppColors.fgLight;
    final muted  = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final subtle = isDark ? AppColors.fgSubtleDark : AppColors.fgSubtleLight;
    final w      = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: card,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 56,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: border),
            ),
            title: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.code, color: Colors.white, size: 15),
                ),
                const SizedBox(width: 10),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'Inter', fontSize: 16,
                      fontWeight: FontWeight.w700, color: fg,
                    ),
                    children: const [
                      TextSpan(text: 'DocGen'),
                      TextSpan(
                        text: ' VN',
                        style: TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(
                  'Đăng nhập',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.primary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16, left: 4),
                child: DgButton.primary(
                  label: 'Đăng ký miễn phí',
                  onPressed: () => context.push('/login/register'),
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: w > 800 ? AppSpacing.s16 : AppSpacing.s6,
                    vertical: AppSpacing.s16,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Text(
                          'Tự động hoá tài liệu mã nguồn',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary, fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s5),
                      Text(
                        'Sinh tài liệu Tiếng Việt\ntừ mã nguồn của bạn',
                        style: AppTypography.h1.copyWith(color: fg, height: 1.2),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'Phân tích codebase và tạo tài liệu có cấu trúc, dễ đọc bằng Tiếng Việt.\nHỗ trợ hơn 20 ngôn ngữ lập trình phổ biến.',
                        style: AppTypography.body.copyWith(color: muted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Wrap(
                        spacing: AppSpacing.s3,
                        runSpacing: AppSpacing.s3,
                        alignment: WrapAlignment.center,
                        children: [
                          DgButton.primary(
                            label: 'Bắt đầu miễn phí',
                            icon: Icons.arrow_forward,
                            onPressed: () => context.push('/login/register'),
                          ),
                          DgButton.secondary(
                            label: 'Xem demo',
                            icon: Icons.play_circle_outline,
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Container(
                  color: card,
                  padding: EdgeInsets.symmetric(
                    horizontal: w > 800 ? AppSpacing.s16 : AppSpacing.s6,
                    vertical: AppSpacing.s12,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Tính năng chính',
                        style: AppTypography.h2.copyWith(color: fg),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      w > 700
                          ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _features(isDark, fg, muted)
                            .map((f) => Expanded(child: f))
                            .toList(),
                      )
                          : Column(
                        children: _features(isDark, fg, muted)
                            .map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                          child: f,
                        ))
                            .toList(),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: w > 800 ? AppSpacing.s16 : AppSpacing.s6,
                    vertical: AppSpacing.s12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thử ngay — không cần đăng ký',
                        style: AppTypography.h2.copyWith(color: fg),
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        'Dán tối đa 500 ký tự mã nguồn để xem demo.',
                        style: AppTypography.body.copyWith(color: muted),
                      ),
                      const SizedBox(height: AppSpacing.s5),
                      Container(
                        decoration: BoxDecoration(
                          color: card,
                          border: Border.all(color: border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(AppSpacing.s4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Mã nguồn',
                                    style: AppTypography.bodyMedium.copyWith(color: fg),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => setState(() => _codeCtrl.text = _sampleCode),
                                  icon: const Icon(Icons.auto_awesome_outlined, size: 14),
                                  label: const Text('Dùng ví dụ'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    textStyle: AppTypography.caption,
                                    foregroundColor: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s2),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.bgDark : AppColors.sunkenLight,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: border),
                              ),
                              padding: const EdgeInsets.all(AppSpacing.s3),
                              child: TextField(
                                controller: _codeCtrl,
                                maxLines: 8,
                                style: AppTypography.code.copyWith(
                                  color: fg, fontSize: 12,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  hintText: _sampleCode,
                                  hintStyle: AppTypography.code.copyWith(
                                    color: subtle, fontSize: 12,
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s3),
                            Row(
                              children: [
                                DgButton.primary(
                                  label: _generating ? 'Đang sinh tài liệu...' : 'Sinh tài liệu',
                                  icon: Icons.bolt,
                                  loading: _generating,
                                  onPressed: _generating ? null : _quickGenerate,
                                ),
                                const SizedBox(width: AppSpacing.s3),
                                Text(
                                  'Giới hạn 500 ký tự / lần thử',
                                  style: AppTypography.caption.copyWith(color: subtle),
                                ),
                              ],
                            ),
                            if (_output != null) ...[
                              const SizedBox(height: AppSpacing.s4),
                              const Divider(),
                              const SizedBox(height: AppSpacing.s3),
                              Text(
                                'Kết quả',
                                style: AppTypography.bodyMedium.copyWith(color: fg),
                              ),
                              const SizedBox(height: AppSpacing.s2),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.s4),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.bgDark : AppColors.sunkenLight,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: border),
                                ),
                                child: Text(
                                  _output!,
                                  style: AppTypography.body.copyWith(color: fg),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s4),
                              DgButton.secondary(
                                label: 'Đăng ký để lưu kết quả',
                                icon: Icons.person_add_outlined,
                                onPressed: () => context.push('/login/register'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  color: card,
                  padding: const EdgeInsets.all(AppSpacing.s6),
                  child: Center(
                    child: Text(
                      '© 2026 DocGen VN — Hiện đại · Chuyên nghiệp · Tin cậy',
                      style: AppTypography.caption.copyWith(color: subtle),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // List tính năng dùng chung cho cả Mobile và Desktop
  List<Widget> _features(bool isDark, Color fg, Color muted) => [
    _FeatureCard(
      icon: Icons.bolt_outlined,
      title: 'Sinh tài liệu tự động',
      desc: 'Phân tích AST và comment để tạo tài liệu có cấu trúc trong vài giây.',
      isDark: isDark, fg: fg, muted: muted,
    ),
    _FeatureCard(
      icon: Icons.language,
      title: 'Tiếng Việt thuần túy',
      desc: 'Tài liệu sinh ra bằng Tiếng Việt rõ ràng, đúng ngữ nghĩa kỹ thuật.',
      isDark: isDark, fg: fg, muted: muted,
    ),
    _FeatureCard(
      icon: Icons.download_outlined,
      title: 'Xuất đa định dạng',
      desc: 'Tải về Markdown, PDF hoặc tích hợp vào pipeline CI/CD qua API.',
      isDark: isDark, fg: fg, muted: muted,
    ),
  ];
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final bool isDark;
  final Color fg;
  final Color muted;

  const _FeatureCard({
    required this.icon, required this.title, required this.desc,
    required this.isDark, required this.fg, required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(title, style: AppTypography.h4.copyWith(color: fg)),
          const SizedBox(height: 6),
          Text(desc, style: AppTypography.body.copyWith(color: muted)),
        ],
      ),
    );
  }
}