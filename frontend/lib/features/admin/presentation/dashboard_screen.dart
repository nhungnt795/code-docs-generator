// lib/features/admin/presentation/dashboard_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart';
import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/dg_card.dart';
import '../../../shared/widgets/dg_misc.dart';
import '../data/admin_repository.dart';

// ── Models nội bộ ────────────────────────────────────────────────────────────
class _Stat {
  final String label, value, delta;
  final IconData icon;
  final bool isPositive;
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.delta,
    required this.isPositive,
  });
}

class _PieItem {
  final String label;
  final double value;
  final Color color;
  const _PieItem(this.label, this.value, this.color);
}

// Bảng màu cố định cho 6 ngôn ngữ
const _langColors = {
  'PYTHON': Color(0xFF3B82F6),
  'JAVASCRIPT': Color(0xFFF59E0B),
  'TYPESCRIPT': Color(0xFF4F46E5),
  'JAVA': Color(0xFFEF4444),
  'CPP': Color(0xFF8B5CF6),
  'RUST': Color(0xFF10B981),
};

const _langDisplayNames = {
  'PYTHON': 'Python',
  'JAVASCRIPT': 'JavaScript',
  'TYPESCRIPT': 'TypeScript',
  'JAVA': 'Java',
  'CPP': 'C++',
  'RUST': 'Rust',
};

// ─────────────────────────────────────────────────────────────────────────────
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _selectedPeriod = 'Tuần này';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final isDesktop = Responsive.isDesktop(context);
    final isMobile = Responsive.isMobile(context);

    final asyncStats = ref.watch(adminStatsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminStatsProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header + filter ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dashboard',
                          style: AppTypography.h2.copyWith(color: fg)),
                      Text('Tổng quan hệ thống',
                          style: AppTypography.body.copyWith(color: muted)),
                    ],
                  ),
                ),
                _PeriodPicker(
                  selected: _selectedPeriod,
                  onChanged: (v) => setState(() => _selectedPeriod = v),
                  isDark: isDark,
                  fg: fg,
                  muted: muted,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s6),

            // ── Stats từ API ─────────────────────────────────────────────
            asyncStats.when(
              loading: () => const _StatsLoading(),
              error: (e, _) => DgEmptyState(
                icon: Icons.error_outline,
                message: 'Không tải được thống kê',
                description: e.toString(),
                actionLabel: 'Thử lại',
                onAction: () => ref.invalidate(adminStatsProvider),
              ),
              data: (stats) {
                final cards = [
                  _Stat(
                    label: 'Tổng người dùng',
                    value: _fmtNum(stats.totalUsers),
                    icon: Icons.people_outline,
                    delta: '+0%',
                    isPositive: true,
                  ),
                  _Stat(
                    label: 'Tài liệu đã tạo',
                    value: _fmtNum(stats.totalDocs),
                    icon: Icons.description_outlined,
                    delta: '+0%',
                    isPositive: true,
                  ),
                  _Stat(
                    label: 'Tài khoản Admin',
                    value: _fmtNum(stats.totalAdmins),
                    icon: Icons.shield_outlined,
                    delta: '+0%',
                    isPositive: true,
                  ),
                ];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isMobile)
                      Column(
                        children: cards
                            .map((s) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: AppSpacing.s4),
                                  child: _StatCard(
                                      stat: s,
                                      isDark: isDark,
                                      fg: fg,
                                      muted: muted),
                                ))
                            .toList(),
                      )
                    else
                      GridView.count(
                        crossAxisCount: isDesktop ? 3 : 2,
                        crossAxisSpacing: AppSpacing.s4,
                        mainAxisSpacing: AppSpacing.s4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 2.2,
                        children: cards
                            .map((s) => _StatCard(
                                stat: s, isDark: isDark, fg: fg, muted: muted))
                            .toList(),
                      ),
                    const SizedBox(height: AppSpacing.s6),

                    // ── Charts ─────────────────────────────────────────
                    if (isDesktop)
                      SizedBox(
                        height: 380,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _LineChartCard(
                                isDark: isDark,
                                fg: fg,
                                muted: muted,
                                totalDocs: stats.totalDocs,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s4),
                            Expanded(
                              flex: 2,
                              child: _PieChartCard(
                                isDark: isDark,
                                fg: fg,
                                muted: muted,
                                stats: stats.byLanguage,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: [
                          SizedBox(
                            height: 340,
                            child: _LineChartCard(
                              isDark: isDark,
                              fg: fg,
                              muted: muted,
                              totalDocs: stats.totalDocs,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s4),
                          SizedBox(
                            height: 360,
                            child: _PieChartCard(
                              isDark: isDark,
                              fg: fg,
                              muted: muted,
                              stats: stats.byLanguage,
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _fmtNum(int n) {
    // Format số có dấu phẩy: 1234 → 1,234
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PERIOD PICKER
// ─────────────────────────────────────────────────────────────────────────────
class _PeriodPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final bool isDark;
  final Color fg, muted;

  const _PeriodPicker({
    required this.selected,
    required this.onChanged,
    required this.isDark,
    required this.fg,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: 16, color: muted),
            const SizedBox(width: 8),
            Text(selected, style: AppTypography.bodyMedium.copyWith(color: fg)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: muted),
          ],
        ),
      ),
      itemBuilder: (context) => ['Hôm nay', 'Tuần này', 'Tháng này', 'Năm nay']
          .map((e) => PopupMenuItem(value: e, child: Text(e)))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING
// ─────────────────────────────────────────────────────────────────────────────
class _StatsLoading extends StatelessWidget {
  const _StatsLoading();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(
            3,
            (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 2 ? 0 : AppSpacing.s4),
                child: DgSkeleton.card(height: 110),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s6),
        DgSkeleton.card(height: 380),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CÁC COMPONENT
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final _Stat stat;
  final bool isDark;
  final Color fg, muted;

  const _StatCard({
    required this.stat,
    required this.isDark,
    required this.fg,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final deltaColor =
        stat.isPositive ? AppColors.success : AppColors.error;
    final deltaBg = stat.isPositive ? AppColors.successSoft : AppColors.errorSoft;

    return DgCard(
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(stat.icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(stat.label,
                    style: AppTypography.bodyMedium.copyWith(color: muted)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(stat.value,
              style: AppTypography.h1.copyWith(color: fg, fontSize: 36)),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: deltaBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  stat.delta,
                  style: AppTypography.caption.copyWith(
                    color: deltaColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text('so với kỳ trước',
                  style: AppTypography.caption.copyWith(color: muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineChartCard extends StatelessWidget {
  final bool isDark;
  final Color fg, muted;
  final int totalDocs;

  const _LineChartCard({
    required this.isDark,
    required this.fg,
    required this.muted,
    required this.totalDocs,
  });

  @override
  Widget build(BuildContext context) {
    final gridColor = isDark ? AppColors.borderDark : const Color(0xFFF3F4F6);

    // Tạo dữ liệu giả lập 7 ngày dựa trên totalDocs (chưa có endpoint /stats/daily)
    final base = (totalDocs / 7).ceil().toDouble();
    final data = [
      base * 0.6, base * 1.0, base * 0.85, base * 1.3,
      base * 1.6, base * 1.4, base * 2.0,
    ];
    final labels = const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return DgCard(
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Yêu cầu sinh tài liệu',
              style: AppTypography.h4.copyWith(color: fg)),
          Text('(Ước tính dựa trên tổng số)',
              style: AppTypography.caption.copyWith(color: muted)),
          const SizedBox(height: AppSpacing.s5),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: base * 0.5 + 1,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: gridColor, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt() >= 0 && v.toInt() < labels.length
                            ? labels[v.toInt()]
                            : '',
                        style: AppTypography.caption.copyWith(color: muted),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: AppTypography.caption.copyWith(color: muted),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value))
                        .toList(),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
                minY: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PieChartCard extends StatefulWidget {
  final bool isDark;
  final Color fg, muted;
  final List<LangStat> stats;

  const _PieChartCard({
    required this.isDark,
    required this.fg,
    required this.muted,
    required this.stats,
  });

  @override
  State<_PieChartCard> createState() => _PieChartCardState();
}

class _PieChartCardState extends State<_PieChartCard> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.stats.isEmpty) {
      return DgCard(
        padding: const EdgeInsets.all(AppSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ngôn ngữ phổ biến',
                style: AppTypography.h4.copyWith(color: widget.fg)),
            const SizedBox(height: AppSpacing.s6),
            Expanded(
              child: Center(
                child: Text(
                  'Chưa có dữ liệu',
                  style: AppTypography.body.copyWith(color: widget.muted),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final total = widget.stats.fold<int>(0, (sum, s) => sum + s.count);
    final items = widget.stats
        .map((s) => _PieItem(
              _langDisplayNames[s.language] ?? s.language,
              total == 0 ? 0 : (s.count / total) * 100,
              _langColors[s.language] ?? AppColors.fgDisabled,
            ))
        .toList();

    return DgCard(
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ngôn ngữ phổ biến',
              style: AppTypography.h4.copyWith(color: widget.fg)),
          const SizedBox(height: AppSpacing.s6),
          Expanded(
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (_, res) => setState(() {
                    _touched =
                        res?.touchedSection?.touchedSectionIndex ?? -1;
                  }),
                ),
                sections: items.asMap().entries.map((e) {
                  final isTouched = e.key == _touched;
                  return PieChartSectionData(
                    value: e.value.value,
                    color: e.value.color,
                    radius: isTouched ? 65 : 55,
                    title: '${e.value.value.toInt()}%',
                    titleStyle: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    showTitle: isTouched || e.value.value >= 10,
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          Center(
            child: Wrap(
              spacing: AppSpacing.s4,
              runSpacing: AppSpacing.s2,
              alignment: WrapAlignment.center,
              children: items
                  .map((item) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: item.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(item.label,
                              style: AppTypography.caption
                                  .copyWith(color: widget.muted)),
                        ],
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
