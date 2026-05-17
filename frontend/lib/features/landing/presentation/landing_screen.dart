// lib/features/landing/presentation/landing_screen.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/dg_button.dart';
import '../widgets/landing_quick_generate.dart';

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});
  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _heroCtrl;
  late final AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Nếu đã đăng nhập → redirect về trang generate
    final user = ref.watch(currentUserProvider);
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/generate');
      });
      return const SizedBox.shrink();
    }

    final isMobile = Responsive.isMobile(context);
    if (isMobile && !kIsWeb) {
      return _MobileAppView(heroCtrl: _heroCtrl, floatCtrl: _floatCtrl);
    }
    return _ScrollableView(heroCtrl: _heroCtrl, floatCtrl: _floatCtrl);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// VIEW: Scrollable (Desktop + Tablet + Mobile Web)
// ════════════════════════════════════════════════════════════════════════════
class _ScrollableView extends StatelessWidget {
  final AnimationController heroCtrl;
  final AnimationController floatCtrl;
  const _ScrollableView({required this.heroCtrl, required this.floatCtrl});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          const _AppBar(),
          SliverToBoxAdapter(
            child: _HeroSection(heroCtrl: heroCtrl, floatCtrl: floatCtrl),
          ),
          const SliverToBoxAdapter(child: _StatsSection()),
          const SliverToBoxAdapter(child: _QuickGenerateSection()),
          const SliverToBoxAdapter(child: _FeaturesSection()),
          const SliverToBoxAdapter(child: _TechStackSection()),
          const SliverToBoxAdapter(child: _CTASection()),
          const SliverToBoxAdapter(child: _Footer()),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// VIEW: Mobile native — vuốt thẻ NGANG
// ════════════════════════════════════════════════════════════════════════════
class _MobileAppView extends StatefulWidget {
  final AnimationController heroCtrl;
  final AnimationController floatCtrl;
  const _MobileAppView({required this.heroCtrl, required this.floatCtrl});

  @override
  State<_MobileAppView> createState() => _MobileAppViewState();
}

class _MobileAppViewState extends State<_MobileAppView> {
  late final PageController _pageCtrl;
  int _currentPage = 0;
  static const int _totalPages = 4;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(
          children: [
            // PageView ngang — bắt đầu sau status bar + appbar
            Positioned(
              top: statusBarHeight + 56,
              left: 0,
              right: 0,
              bottom: 0,
              child: PageView(
                controller: _pageCtrl,
                scrollDirection: Axis.horizontal,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _MobileCard(child: _HeroSection(
                    heroCtrl: widget.heroCtrl,
                    floatCtrl: widget.floatCtrl,
                    compact: true,
                  )),
                  const _MobileCard(child: _StatsSection(compact: true)),
                  const _MobileCard(child: _FeaturesSection(compact: true)),
                  const _MobileCard(child: _CTASection(compact: true)),
                ],
              ),
            ),
            // AppBar nằm dưới status bar
            Positioned(
              top: statusBarHeight,
              left: 0,
              right: 0,
              child: const _AppBarMobile(),
            ),
            // Chấm chỉ trang — nằm dưới màn hình
            Positioned(
              bottom: 20 + MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (i) {
                  final active = i == _currentPage;
                  return GestureDetector(
                    onTap: () => _pageCtrl.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Hint vuốt ngang ở trang đầu
            if (_currentPage == 0)
              Positioned(
                bottom: 48 + MediaQuery.of(context).padding.bottom,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 8),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeInOut,
                        builder: (_, v, __) => Transform.translate(
                          offset: Offset(v, 0),
                          child: const Icon(
                            Icons.keyboard_arrow_right,
                            color: AppColors.primary,
                          ),
                        ),
                        onEnd: () => setState(() {}),
                      ),
                      Text(
                        'Vuốt để khám phá',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MobileCard extends StatelessWidget {
  final Widget child;
  const _MobileCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final bottomPad = 80.0 + MediaQuery.of(context).padding.bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomPad),
                child: Center(child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// APPBAR
// ════════════════════════════════════════════════════════════════════════════
class _AppBar extends StatelessWidget {
  const _AppBar();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;

    return SliverAppBar(
      backgroundColor: card.withOpacity(0.85),
      elevation: 0,
      pinned: true,
      automaticallyImplyLeading: false,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: border.withOpacity(0.5)),
              ),
            ),
          ),
        ),
      ),
      titleSpacing: 16,
      title: Stack(
        alignment: Alignment.center,
        children: [
          // Nav links — căn giữa tuyệt đối
          if (!isMobile)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NavLink(
                  label: 'Giới thiệu',
                  onTap: () => context.go('/about'),
                  color: muted,
                ),
                const SizedBox(width: 28),
                _NavLink(
                  label: 'Tải xuống',
                  onTap: () => context.go('/download'),
                  color: muted,
                ),
                const SizedBox(width: 28),
                _NavLink(
                  label: 'Liên hệ',
                  onTap: () => context.go('/contact'),
                  color: muted,
                ),
              ],
            ),
          // Logo + Buttons — hai đầu
          Row(
            children: [
              _LogoMark(),
              const SizedBox(width: 10),
              RichText(
                text: TextSpan(
                  style: AppTypography.h4.copyWith(color: fg, fontSize: 18),
                  children: const [
                    TextSpan(text: 'DocGen'),
                    TextSpan(
                      text: ' VN',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              DgButton.secondary(
                label: 'Đăng nhập',
                onPressed: () => context.push('/login'),
              ),
              const SizedBox(width: 8),
              if (!isMobile) ...[
                DgButton.primary(
                  label: 'Đăng ký miễn phí',
                  onPressed: () => context.push('/login/register'),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AppBarMobile extends StatelessWidget {
  const _AppBarMobile();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: card.withOpacity(0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          _LogoMark(),
          const SizedBox(width: 10),
          RichText(
            text: TextSpan(
              style: AppTypography.h4.copyWith(color: fg, fontSize: 18),
              children: const [
                TextSpan(text: 'DocGen'),
                TextSpan(
                  text: ' VN',
                  style: TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const Spacer(),
          DgButton.secondary(
            label: 'Đăng nhập',
            onPressed: () => context.push('/login'),
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
    );
  }
}

class _NavLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _NavLink({
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: AppTypography.bodyMedium.copyWith(
                  color: _hovered ? AppColors.primary : widget.color,
                  fontWeight: _hovered ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 2,
                width: _hovered ? 40 : 0,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HERO
// ════════════════════════════════════════════════════════════════════════════
class _HeroSection extends StatelessWidget {
  final AnimationController heroCtrl;
  final AnimationController floatCtrl;
  final bool compact;

  const _HeroSection({
    required this.heroCtrl,
    required this.floatCtrl,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = Responsive.isMobile(context);

    final fadeUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: heroCtrl, curve: Curves.easeOutCubic));

    return Container(
      width: double.infinity,
      constraints: compact ? const BoxConstraints(minHeight: double.infinity) : const BoxConstraints(),
      padding: EdgeInsets.symmetric(
        horizontal: w > 800 ? 64 : (compact ? 20 : 24),
        vertical: compact ? 0 : 64,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
              : [const Color(0xFFF5F3FF), const Color(0xFFEEF2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          ..._FloatingShapes(floatCtrl: floatCtrl).build(context, w),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: SlideTransition(
                position: fadeUp,
                child: FadeTransition(
                  opacity: heroCtrl,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.success.withOpacity(0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'GraphRAG · Tiếng Việt · Miễn phí',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: compact ? 16 : 28),
                      ShaderMask(
                        shaderCallback: (rect) => const LinearGradient(
                          colors: [
                            Color(0xFF4F46E5),
                            Color(0xFF7C3AED),
                            Color(0xFFEC4899),
                          ],
                        ).createShader(rect),
                        child: Text(
                          isMobile
                              ? 'Sinh tài liệu\nTiếng Việt từ code'
                              : 'Sinh tài liệu Tiếng Việt\ntừ mã nguồn trong vài giây',
                          textAlign: TextAlign.center,
                          style: AppTypography.h1.copyWith(
                            color: Colors.white,
                            fontSize: isMobile ? 32 : 52,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 14 : 20),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: compact ? 0 : 24),
                        child: Text(
                          'Hệ thống AI phân tích cấu trúc mã nguồn (AST + GraphRAG) '
                              'và sinh tài liệu kỹ thuật bằng Tiếng Việt rõ ràng, chính xác. '
                              'Hỗ trợ 6 ngôn ngữ phổ biến.',
                          textAlign: TextAlign.center,
                          style: AppTypography.body.copyWith(
                            color: muted,
                            fontSize: isMobile ? 14 : 16,
                            height: 1.65,
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 22 : 36),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          DgButton.primary(
                            label: 'Bắt đầu miễn phí',
                            icon: Icons.arrow_forward,
                            onPressed: () =>
                                context.push('/login/register'),
                          ),
                          DgButton.secondary(
                            label: 'Dùng thử ngay',
                            icon: Icons.play_circle_outline,
                            onPressed: () {
                              Scrollable.ensureVisible(
                                context,
                                duration:
                                const Duration(milliseconds: 400),
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 14 : 20),
                      Text(
                        '✓ Không cần thẻ tín dụng    ✓ Miễn phí trọn đời cho cá nhân',
                        style:
                        AppTypography.caption.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingShapes {
  final AnimationController floatCtrl;
  _FloatingShapes({required this.floatCtrl});

  List<Widget> build(BuildContext context, double w) {
    return [
      AnimatedBuilder(
        animation: floatCtrl,
        builder: (_, __) => Positioned(
          top: 40 + math.sin(floatCtrl.value * math.pi) * 10,
          left: 24,
          child: _DecoBubble(
            color: const Color(0xFF7C3AED).withOpacity(0.15),
            size: 80,
          ),
        ),
      ),
      AnimatedBuilder(
        animation: floatCtrl,
        builder: (_, __) => Positioned(
          top: 100 - math.sin(floatCtrl.value * math.pi) * 12,
          right: 60,
          child: _DecoBubble(
            color: AppColors.primary.withOpacity(0.18),
            size: 120,
          ),
        ),
      ),
      if (w > 700)
        AnimatedBuilder(
          animation: floatCtrl,
          builder: (_, __) => Positioned(
            bottom: 40 + math.cos(floatCtrl.value * math.pi) * 10,
            left: 80,
            child: _DecoBubble(
              color: const Color(0xFFEC4899).withOpacity(0.12),
              size: 60,
            ),
          ),
        ),
    ];
  }
}

class _DecoBubble extends StatelessWidget {
  final Color color;
  final double size;
  const _DecoBubble({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// STATS
// ════════════════════════════════════════════════════════════════════════════
class _StatsSection extends StatelessWidget {
  final bool compact;
  const _StatsSection({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final w = MediaQuery.sizeOf(context).width;
    const stats = [
      _Stat(value: 6, suffix: '+', label: 'Ngôn ngữ\nlập trình'),
      _Stat(value: 1200, suffix: '+', label: 'Tài liệu\nđã sinh'),
      _Stat(value: 98, suffix: '%', label: 'Độ hài lòng\nngười dùng'),
      _Stat(value: 12, suffix: 's', label: 'Thời gian sinh\ntrung bình'),
    ];
    return Container(
      color: card,
      constraints: compact ? const BoxConstraints(minHeight: double.infinity) : const BoxConstraints(),
      padding: EdgeInsets.symmetric(
        horizontal: w > 800 ? 64 : 20,
        vertical: compact ? 0 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: w > 700
              ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: stats
                .map((s) => Expanded(child: _StatTile(stat: s)))
                .toList(),
          )
              : Wrap(
            spacing: 16,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: stats
                .map((s) => SizedBox(
              width: (w - 48) / 2,
              child: _StatTile(stat: s),
            ))
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _Stat {
  final int value;
  final String suffix;
  final String label;
  const _Stat({required this.value, required this.suffix, required this.label});
}

class _StatTile extends StatefulWidget {
  final _Stat stat;
  const _StatTile({required this.stat});

  @override
  State<_StatTile> createState() => _StatTileState();
}

class _StatTileState extends State<_StatTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final v = (widget.stat.value *
            Curves.easeOutCubic.transform(_c.value))
            .round();
        return Column(
          children: [
            ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              ).createShader(rect),
              child: Text(
                '$v${widget.stat.suffix}',
                style: AppTypography.h1.copyWith(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.stat.label,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: muted),
            ),
          ],
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// QUICK GENERATE
// ════════════════════════════════════════════════════════════════════════════
class _QuickGenerateSection extends StatelessWidget {
  final bool compact;
  const _QuickGenerateSection({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final w = MediaQuery.sizeOf(context).width;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: w > 800 ? 64 : 20,
        vertical: compact ? 20 : 64,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            children: [
              Text(
                'Trải nghiệm trong 30 giây',
                style: AppTypography.h2
                    .copyWith(color: fg, fontSize: compact ? 20 : 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Dán mã nguồn của bạn và xem ngay tài liệu sinh ra. Không cần đăng ký, không cần cài đặt.',
                style: AppTypography.body.copyWith(color: muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const LandingQuickGenerate(),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FEATURES
// ════════════════════════════════════════════════════════════════════════════
class _FeaturesSection extends StatelessWidget {
  final bool compact;
  const _FeaturesSection({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final w = MediaQuery.sizeOf(context).width;
    const features = [
      _Feature(
        icon: Icons.auto_awesome,
        title: 'GraphRAG thông minh',
        desc: 'Phân tích AST + đồ thị tri thức để hiểu code, không phải đoán mò.',
        gradient: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
      ),
      _Feature(
        icon: Icons.translate,
        title: 'Tiếng Việt chuẩn',
        desc: 'Thuật ngữ kỹ thuật chính xác, câu chữ tự nhiên không gượng gạo.',
        gradient: [Color(0xFF7C3AED), Color(0xFFEC4899)],
      ),
      _Feature(
        icon: Icons.download_outlined,
        title: 'Xuất 3 định dạng',
        desc: 'Tải về Markdown, PDF, Word — đưa thẳng vào báo cáo hoặc wiki.',
        gradient: [Color(0xFFEC4899), Color(0xFFEF4444)],
      ),
      _Feature(
        icon: Icons.history,
        title: 'Lịch sử & phiên bản',
        desc: 'Mọi tài liệu được lưu lại. Sửa lại, so sánh phiên bản dễ dàng.',
        gradient: [Color(0xFFF59E0B), Color(0xFFEF4444)],
      ),
      _Feature(
        icon: Icons.bolt,
        title: 'Nhanh & ổn định',
        desc: 'Trung bình 12 giây/file. Backend chạy trên Groq Cloud.',
        gradient: [Color(0xFF22C55E), Color(0xFF4F46E5)],
      ),
      _Feature(
        icon: Icons.shield_outlined,
        title: 'Bảo mật dữ liệu',
        desc: 'Code chỉ lưu trong tài khoản của bạn, không chia sẻ ra ngoài.',
        gradient: [Color(0xFF3B82F6), Color(0xFF7C3AED)],
      ),
    ];
    final col = w > 1000 ? 3 : (w > 640 ? 2 : 1);
    return Container(
      color: card,
      constraints: compact ? const BoxConstraints(minHeight: double.infinity) : const BoxConstraints(),
      padding: EdgeInsets.symmetric(
        horizontal: w > 800 ? 64 : 20,
        vertical: compact ? 0 : 72,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              Text(
                'Mọi thứ bạn cần',
                style: AppTypography.h2
                    .copyWith(color: fg, fontSize: compact ? 22 : 32),
              ),
              const SizedBox(height: 10),
              Text(
                'Một bộ công cụ hoàn chỉnh để biến code thành tài liệu chuyên nghiệp',
                style: AppTypography.body.copyWith(color: muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                children: features.map((f) {
                  final width = col == 1
                      ? double.infinity
                      : (1180 - 18 * (col - 1)) / col;
                  return SizedBox(
                    width: col == 1 ? double.infinity : width,
                    child: _FeatureCard(feature: f),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String desc;
  final List<Color> gradient;
  const _Feature({
    required this.icon,
    required this.title,
    required this.desc,
    required this.gradient,
  });
}

class _FeatureCard extends StatefulWidget {
  final _Feature feature;
  const _FeatureCard({required this.feature});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: card,
          border: Border.all(
            color: _hover ? AppColors.primary.withOpacity(0.3) : border,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: _hover
              ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.feature.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
              Icon(widget.feature.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 16),
            Text(widget.feature.title,
                style: AppTypography.h4
                    .copyWith(color: fg, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(widget.feature.desc,
                style: AppTypography.body.copyWith(color: muted)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TECH STACK
// ════════════════════════════════════════════════════════════════════════════
class _TechStackSection extends StatelessWidget {
  const _TechStackSection();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final w = MediaQuery.sizeOf(context).width;
    const techs = [
      _Tech(name: 'Flutter', icon: Icons.flutter_dash, color: Color(0xFF02569B)),
      _Tech(name: 'FastAPI', icon: Icons.api, color: Color(0xFF009688)),
      _Tech(name: 'PostgreSQL', icon: Icons.storage, color: Color(0xFF336791)),
      _Tech(name: 'Docker', icon: Icons.developer_board, color: Color(0xFF2496ED)),
      _Tech(name: 'AWS EC2', icon: Icons.cloud, color: Color(0xFFFF9900)),
      _Tech(name: 'Nginx', icon: Icons.dns, color: Color(0xFF009639)),
      _Tech(name: 'Groq', icon: Icons.bolt, color: Color(0xFFF55036)),
      _Tech(name: 'Tree-sitter', icon: Icons.account_tree, color: Color(0xFF7C3AED)),
    ];
    return Container(
      padding:
      EdgeInsets.symmetric(horizontal: w > 800 ? 64 : 20, vertical: 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Text('Công nghệ chúng tôi dùng',
                  style: AppTypography.h2.copyWith(color: fg, fontSize: 24)),
              const SizedBox(height: 8),
              Text(
                'Stack hiện đại, mã nguồn mở, có thể mở rộng',
                style: AppTypography.body.copyWith(color: muted),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: techs.map((t) => _TechChip(tech: t)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tech {
  final String name;
  final IconData icon;
  final Color color;
  const _Tech({required this.name, required this.icon, required this.color});
}

class _TechChip extends StatelessWidget {
  final _Tech tech;
  const _TechChip({required this.tech});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tech.color.withOpacity(0.08),
        border: Border.all(color: tech.color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tech.icon, size: 16, color: tech.color),
          const SizedBox(width: 8),
          Text(tech.name,
              style: AppTypography.bodyMedium
                  .copyWith(color: fg, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CTA
// ════════════════════════════════════════════════════════════════════════════
class _CTASection extends StatelessWidget {
  final bool compact;
  const _CTASection({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final inner = Container(
      margin: EdgeInsets.symmetric(
          horizontal: w > 800 ? 64 : 20, vertical: compact ? 0 : 56),
      padding: EdgeInsets.all(compact ? 28 : 48),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sẵn sàng tăng tốc tài liệu hóa?',
            style: AppTypography.h2.copyWith(
                color: Colors.white, fontSize: compact ? 22 : 28),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Tạo tài khoản miễn phí và bắt đầu tài liệu hóa codebase của bạn ngay hôm nay.',
            style: AppTypography.body.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => context.push('/login/register'),
                icon: const Icon(Icons.rocket_launch, size: 18),
                label: const Text('Tạo tài khoản miễn phí'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 14),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/about'),
                icon: const Icon(Icons.info_outline,
                    size: 18, color: Colors.white),
                label: const Text('Tìm hiểu thêm',
                    style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white70),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (compact) {
      return SizedBox(
        width: double.infinity,
        child: inner,
      );
    }
    return inner;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FOOTER
// ════════════════════════════════════════════════════════════════════════════
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final subtle = isDark ? AppColors.fgSubtleDark : AppColors.fgSubtleLight;
    final w = MediaQuery.sizeOf(context).width;
    const links = [
      _FooterLink('Giới thiệu', '/about'),
      _FooterLink('Liên hệ', '/contact'),
      _FooterLink('Chính sách bảo mật', '/privacy'),
      _FooterLink('Điều khoản sử dụng', '/terms'),
    ];
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: w > 800 ? 64 : 20, vertical: 36),
      decoration: BoxDecoration(
        color: card,
        border: Border(top: BorderSide(color: border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Wrap(
                spacing: 28,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: links
                    .map((l) => MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: InkWell(
                  onTap: () => context.push(l.path),
                  child: Text(
                    l.label,
                    style: AppTypography.bodySmall
                        .copyWith(color: muted),
                  ),
                )))
                    .toList(),
              ),
              const SizedBox(height: 14),
              Text(
                '© 2026 DocGen VN - Dự án Học phần Khai phá Dữ liệu · Trường Đại học Khoa học Tự nhiên · ĐHQGHN',
                style: AppTypography.caption.copyWith(color: subtle),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterLink {
  final String label;
  final String path;
  const _FooterLink(this.label, this.path);
}