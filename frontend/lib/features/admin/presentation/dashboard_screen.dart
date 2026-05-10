// lib/features/admin/presentation/dashboard_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/dg_card.dart';

// ── Định nghĩa các Models ở ngoài cùng để tránh lỗi Scope ──
class _Stat {
  final String label, value, delta;
  final IconData icon;
  final bool isPositive;
  const _Stat({required this.label, required this.value, required this.icon, required this.delta, required this.isPositive});
}

class _PieItem {
  final String label;
  final double value;
  final Color color;
  const _PieItem(this.label, this.value, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedPeriod = 'Tuần này';
  DateTimeRange? _customDateRange;

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(primary: AppColors.primary)
                : const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedPeriod = 'Tùy chỉnh';
        _customDateRange = picked;
      });
    }
  }

  String get _periodLabel {
    if (_selectedPeriod == 'Tùy chỉnh' && _customDateRange != null) {
      final start = DateFormat('dd/MM').format(_customDateRange!.start);
      final end = DateFormat('dd/MM').format(_customDateRange!.end);
      return '$start - $end';
    }
    return _selectedPeriod;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final isDesktop = Responsive.isDesktop(context);
    final isMobile = Responsive.isMobile(context);

    final stats = [
      const _Stat(label: 'Tổng người dùng', value: '1,248', icon: Icons.people_outline, delta: '+12%', isPositive: true),
      const _Stat(label: 'Tài liệu đã tạo', value: '8,432', icon: Icons.description_outlined, delta: '+24%', isPositive: true),
      const _Stat(label: 'Yêu cầu xử lý', value: '342', icon: Icons.bolt_outlined, delta: '-5%', isPositive: false),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dashboard', style: AppTypography.h2.copyWith(color: fg)),
                    Text('Tổng quan hệ thống', style: AppTypography.body.copyWith(color: muted)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'Tùy chỉnh') {
                    _pickDateRange();
                  } else {
                    setState(() {
                      _selectedPeriod = val;
                      _customDateRange = null;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.cardLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 16, color: muted),
                      const SizedBox(width: 8),
                      Text(_periodLabel, style: AppTypography.bodyMedium.copyWith(color: fg)),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, size: 16, color: muted),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  'Hôm nay', 'Tuần này', 'Tháng này', 'Năm nay', 'Tùy chỉnh'
                ].map((e) => PopupMenuItem(value: e, child: Text(e))).toList(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s6),

          if (isMobile)
            Column(
              children: stats.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                child: _StatCard(stat: s, isDark: isDark, fg: fg, muted: muted),
              )).toList(),
            )
          else
            GridView.count(
              crossAxisCount: isDesktop ? 3 : 2,
              crossAxisSpacing: AppSpacing.s4,
              mainAxisSpacing: AppSpacing.s4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.2,
              children: stats.map((s) => _StatCard(stat: s, isDark: isDark, fg: fg, muted: muted)).toList(),
            ),

          const SizedBox(height: AppSpacing.s4),
          _SuccessRateCard(isDark: isDark, fg: fg, muted: muted),
          const SizedBox(height: AppSpacing.s6),

          if (isDesktop)
            SizedBox(
              height: 380,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: _LineChartCard(isDark: isDark, fg: fg, muted: muted)),
                  const SizedBox(width: AppSpacing.s4),
                  Expanded(flex: 2, child: _PieChartCard(isDark: isDark, fg: fg, muted: muted)),
                ],
              ),
            )
          else
            Column(
              children: [
                SizedBox(height: 340, child: _LineChartCard(isDark: isDark, fg: fg, muted: muted)),
                const SizedBox(height: AppSpacing.s4),
                SizedBox(height: 360, child: _PieChartCard(isDark: isDark, fg: fg, muted: muted)),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Các Component ──

class _StatCard extends StatelessWidget {
  final _Stat stat;
  final bool isDark;
  final Color fg, muted;

  const _StatCard({required this.stat, required this.isDark, required this.fg, required this.muted});

  @override
  Widget build(BuildContext context) {
    final deltaColor = stat.isPositive ? AppColors.success : AppColors.error;
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
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(8)),
                child: Icon(stat.icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(stat.label, style: AppTypography.bodyMedium.copyWith(color: muted)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(stat.value, style: AppTypography.h1.copyWith(color: fg, fontSize: 36)),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: deltaBg, borderRadius: BorderRadius.circular(4)),
                child: Text(stat.delta, style: AppTypography.caption.copyWith(color: deltaColor, fontWeight: FontWeight.w600)),
              ),
              Text('so với kỳ trước', style: AppTypography.caption.copyWith(color: muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuccessRateCard extends StatelessWidget {
  final bool isDark;
  final Color fg, muted;
  const _SuccessRateCard({required this.isDark, required this.fg, required this.muted});

  @override
  Widget build(BuildContext context) {
    const double successRate = 0.94;
    const double failRate = 1.0 - successRate;

    return DgCard(
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tỷ lệ sinh tài liệu thành công', style: AppTypography.h4.copyWith(color: fg)),
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thành công', style: AppTypography.caption.copyWith(color: muted)),
                    Text('${(successRate * 100).toInt()}%', style: AppTypography.h3.copyWith(color: AppColors.success)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Thất bại', style: AppTypography.caption.copyWith(color: muted)),
                    Text('${(failRate * 100).toInt()}%', style: AppTypography.h3.copyWith(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Expanded(flex: (successRate * 100).toInt(), child: Container(height: 8, color: AppColors.success)),
                Expanded(flex: (failRate * 100).toInt(), child: Container(height: 8, color: AppColors.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartCard extends StatelessWidget {
  final bool isDark;
  final Color fg, muted;
  const _LineChartCard({required this.isDark, required this.fg, required this.muted});

  @override
  Widget build(BuildContext context) {
    final gridColor = isDark ? AppColors.borderDark : const Color(0xFFF3F4F6);
    final data = const [42.0, 68.0, 55.0, 89.0, 120.0, 98.0, 145.0];
    final labels = const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return DgCard(
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Yêu cầu sinh tài liệu', style: AppTypography.h4.copyWith(color: fg)),
          const SizedBox(height: AppSpacing.s6),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true, drawVerticalLine: false, horizontalInterval: 40,
                  getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, interval: 1,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt() >= 0 && v.toInt() < labels.length ? labels[v.toInt()] : '',
                        style: AppTypography.caption.copyWith(color: muted),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, interval: 40, reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: AppTypography.caption.copyWith(color: muted)),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                    isCurved: true, color: AppColors.primary, barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [AppColors.primary.withOpacity(0.2), Colors.transparent],
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
  const _PieChartCard({required this.isDark, required this.fg, required this.muted});

  @override
  State<_PieChartCard> createState() => _PieChartCardState();
}

class _PieChartCardState extends State<_PieChartCard> {
  int _touched = -1;

  // Đã gán rõ kiểu dữ liệu List<_PieItem> để trình biên dịch hiểu
  final List<_PieItem> _items = const [
    _PieItem('Python',     35.0, Color(0xFF3B82F6)),
    _PieItem('JavaScript', 25.0, Color(0xFFF59E0B)),
    _PieItem('TypeScript', 15.0, Color(0xFF4F46E5)),
    _PieItem('Java',       10.0, Color(0xFFEF4444)),
    _PieItem('C++',        8.0,  Color(0xFF8B5CF6)),
    _PieItem('Rust',       7.0,  Color(0xFF10B981)),
  ];

  @override
  Widget build(BuildContext context) {
    return DgCard(
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ngôn ngữ phổ biến', style: AppTypography.h4.copyWith(color: widget.fg)),
          const SizedBox(height: AppSpacing.s6),
          Expanded(
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (_, res) => setState(() {
                    _touched = res?.touchedSection?.touchedSectionIndex ?? -1;
                  }),
                ),
                sections: _items.asMap().entries.map((e) {
                  final isTouched = e.key == _touched;
                  return PieChartSectionData(
                    value: e.value.value,
                    color: e.value.color,
                    radius: isTouched ? 65 : 55,
                    title: '${e.value.value.toInt()}%',
                    titleStyle: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
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
              children: _items.map((item) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(item.label, style: AppTypography.caption.copyWith(color: widget.muted)),
                ],
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}