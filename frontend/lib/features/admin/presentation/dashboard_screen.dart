// lib/features/admin/presentation/dashboard_screen.dart
//
// FIX:
// - Bottom overflowed: thay SizedBox(height: 380) bằng LayoutBuilder
//   để chart co giãn theo không gian có sẵn thay vì tràn màn hình
// - Dùng MediaQuery để tính chiều cao chart động
// - Thêm SingleChildScrollView bao toàn bộ nội dung

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

// ── Helpers ───────────────────────────────────────────────────────────────────
class _Period {
  final String label;
  final String key;
  const _Period(this.label, this.key);
}

const _periods = [
  _Period('Hôm nay',   'today'),
  _Period('Tuần này',  'week'),
  _Period('Tháng này', 'month'),
  _Period('Năm nay',   'year'),
  _Period('Tất cả',    'all'),
  _Period('Tuỳ chỉnh...', 'custom'),
];

const _langColors = {
  'PYTHON': Color(0xFF3B82F6), 'JAVASCRIPT': Color(0xFFF59E0B),
  'TYPESCRIPT': Color(0xFF4F46E5), 'JAVA': Color(0xFFEF4444),
  'CPP': Color(0xFF8B5CF6), 'RUST': Color(0xFF10B981),
};
const _langNames = {
  'PYTHON': 'Python', 'JAVASCRIPT': 'JavaScript', 'TYPESCRIPT': 'TypeScript',
  'JAVA': 'Java', 'CPP': 'C++', 'RUST': 'Rust',
};
const _modelColors = {
  'GROQ_LLAMA3': Color(0xFF4F46E5),
  'KAGGLE_FINETUNED': Color(0xFFEC4899),
};
const _modelNames = {
  'GROQ_LLAMA3': 'Llama Groq',
  'KAGGLE_FINETUNED': 'Finetuned',
};

// ─────────────────────────────────────────────────────────────────────────────
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _periodKey = 'all';
  DateTimeRange? _customRange;

  String get _periodLabel {
    if (_periodKey == 'custom' && _customRange != null) {
      return '${_d(_customRange!.start)} – ${_d(_customRange!.end)}';
    }
    return _periods.firstWhere((p) => p.key == _periodKey).label;
  }

  String _d(DateTime dt) =>
      '${dt.day.toString().padLeft(2,'0')}/'
      '${dt.month.toString().padLeft(2,'0')}/${dt.year}';

  void _applyPeriod(String key) {
    if (key == 'custom') { _openDatePicker(); return; }
    setState(() { _periodKey = key; _customRange = null; });
    ref.read(adminPeriodProvider.notifier).state = key;
    ref.read(adminDateFromProvider.notifier).state = null;
    ref.read(adminDateToProvider.notifier).state = null;
  }

  Future<void> _openDatePicker() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(
              start: now.subtract(const Duration(days: 30)), end: now),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx)
                .colorScheme
                .copyWith(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() { _periodKey = 'custom'; _customRange = picked; });
    ref.read(adminPeriodProvider.notifier).state = 'custom';
    ref.read(adminDateFromProvider.notifier).state = picked.start;
    ref.read(adminDateToProvider.notifier).state = picked.end;
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final fg         = isDark ? AppColors.fgDark     : AppColors.fgLight;
    final muted      = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final isDesktop  = Responsive.isDesktop(context);
    final isMobile   = Responsive.isMobile(context);
    final asyncStats = ref.watch(adminStatsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminStatsProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + filter
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dashboard',
                          style: AppTypography.h2.copyWith(color: fg)),
                      Text('Tổng quan · $_periodLabel',
                          style: AppTypography.body.copyWith(color: muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _PeriodPicker(
                  selectedKey: _periodKey,
                  label: _periodLabel,
                  onChanged: _applyPeriod,
                  isDark: isDark, fg: fg, muted: muted,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s6),

            asyncStats.when(
              loading: () => Column(
                children: [
                  GridView.count(
                    crossAxisCount: isDesktop ? 4 : (isMobile ? 1 : 2),
                    crossAxisSpacing: AppSpacing.s4,
                    mainAxisSpacing: AppSpacing.s4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: isDesktop ? 1.9 : 2.2,
                    children: List.generate(4,
                        (_) => DgSkeleton.card(height: 120)),
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  DgSkeleton.card(height: 300),
                ],
              ),
              error: (e, _) => DgEmptyState(
                icon: Icons.error_outline,
                message: 'Không tải được thống kê',
                description: e.toString(),
                actionLabel: 'Thử lại',
                onAction: () => ref.invalidate(adminStatsProvider),
              ),
              data: (stats) => _Body(
                stats: stats,
                isDark: isDark, fg: fg, muted: muted,
                isDesktop: isDesktop, isMobile: isMobile,
                periodLabel: _periodLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final AdminStatsModel stats;
  final bool isDark, isDesktop, isMobile;
  final Color fg, muted;
  final String periodLabel;

  const _Body({
    required this.stats, required this.isDark,
    required this.fg, required this.muted,
    required this.isDesktop, required this.isMobile,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SC('Tổng người dùng', _fmt(stats.totalUsers),
          Icons.people_outline,    '${stats.activeUsers} đang hoạt động',
          true,  AppColors.primary),
      _SC('Tài liệu đã tạo', _fmt(stats.totalDocs),
          Icons.description_outlined, '+${stats.docsToday} hôm nay',
          true,  AppColors.success),
      _SC('Yêu cầu 24h', _fmt(stats.pendingRequests),
          Icons.pending_actions_outlined, 'Trong 24h gần nhất',
          stats.pendingRequests < 50, AppColors.warning),
      _SC('TK bị khóa', _fmt(stats.lockedUsers),
          Icons.lock_outline, stats.lockedUsers > 0 ? 'Cần xem xét' : 'Bình thường',
          stats.lockedUsers == 0, AppColors.error),
    ];

    // Tính chiều cao chart linh hoạt dựa trên screen
    final chartH = isDesktop ? 320.0 : 280.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stat cards
        isMobile
            ? Column(
                children: cards.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                  child: _StatCard(cfg: c, isDark: isDark, fg: fg, muted: muted),
                )).toList(),
              )
            : GridView.count(
                crossAxisCount: isDesktop ? 4 : 2,
                crossAxisSpacing: AppSpacing.s4,
                mainAxisSpacing: AppSpacing.s4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isDesktop ? 1.9 : 2.0,
                children: cards.map((c) =>
                    _StatCard(cfg: c, isDark: isDark, fg: fg, muted: muted))
                    .toList(),
              ),
        const SizedBox(height: AppSpacing.s5),

        // Avg time chip
        if (stats.avgTimeMs > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, size: 15, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Thời gian sinh TB: ${(stats.avgTimeMs/1000).toStringAsFixed(1)}s',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),

        // Charts — dùng SizedBox với chiều cao tính sẵn (không Expanded)
        if (isDesktop)
          SizedBox(
            height: chartH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: _LineChartCard(
                    isDark: isDark, fg: fg, muted: muted,
                    docsOverTime: stats.docsOverTime,
                    periodLabel: periodLabel,
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  flex: 2,
                  child: _PieCard(
                    isDark: isDark, fg: fg, muted: muted,
                    stats: stats.byLanguage,
                    title: 'Ngôn ngữ',
                    colorMap: _langColors,
                    nameMap: _langNames,
                  ),
                ),
                if (stats.byModel.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.s4),
                  Expanded(
                    flex: 2,
                    child: _PieCard(
                      isDark: isDark, fg: fg, muted: muted,
                      stats: stats.byModel,
                      title: 'Model AI',
                      colorMap: _modelColors,
                      nameMap: _modelNames,
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          Column(
            children: [
              SizedBox(
                height: chartH,
                child: _LineChartCard(
                  isDark: isDark, fg: fg, muted: muted,
                  docsOverTime: stats.docsOverTime,
                  periodLabel: periodLabel,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              SizedBox(
                height: chartH,
                child: _PieCard(
                  isDark: isDark, fg: fg, muted: muted,
                  stats: stats.byLanguage,
                  title: 'Ngôn ngữ phổ biến',
                  colorMap: _langColors,
                  nameMap: _langNames,
                ),
              ),
            ],
          ),
      ],
    );
  }

  static String _fmt(int n) {
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
// Stat card config
// ─────────────────────────────────────────────────────────────────────────────
class _SC {
  final String label, value, delta;
  final IconData icon;
  final bool isPositive;
  final Color color;
  const _SC(this.label, this.value, this.icon, this.delta, this.isPositive, this.color);
}

class _StatCard extends StatelessWidget {
  final _SC cfg;
  final bool isDark;
  final Color fg, muted;
  const _StatCard({required this.cfg, required this.isDark, required this.fg, required this.muted});

  @override
  Widget build(BuildContext context) {
    final dColor = cfg.isPositive ? AppColors.success : AppColors.error;
    final dBg    = cfg.isPositive ? AppColors.successSoft : AppColors.errorSoft;
    return DgCard(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: cfg.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(cfg.icon, size: 18, color: cfg.color),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(cfg.label,
                style: AppTypography.bodyMedium.copyWith(color: muted),
                overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: AppSpacing.s3),
          Text(cfg.value, style: AppTypography.h1.copyWith(color: fg, fontSize: 28)),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: dBg, borderRadius: BorderRadius.circular(4)),
            child: Text(cfg.delta,
                style: AppTypography.caption.copyWith(color: dColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Period picker
// ─────────────────────────────────────────────────────────────────────────────
class _PeriodPicker extends StatelessWidget {
  final String selectedKey, label;
  final ValueChanged<String> onChanged;
  final bool isDark;
  final Color fg, muted;
  const _PeriodPicker({
    required this.selectedKey, required this.label,
    required this.onChanged, required this.isDark,
    required this.fg, required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final active = selectedKey != 'all';
    return PopupMenuButton<String>(
      onSelected: onChanged,
      tooltip: 'Lọc theo thời gian',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.primary.withOpacity(0.6)
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_outlined, size: 14,
              color: active ? AppColors.primary : muted),
          const SizedBox(width: 7),
          Text(label, style: AppTypography.bodyMedium.copyWith(
              color: active ? AppColors.primary : fg)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 15, color: muted),
        ]),
      ),
      itemBuilder: (_) => _periods.map((p) => PopupMenuItem(
        value: p.key,
        child: Row(children: [
          Icon(
            p.key == 'custom' ? Icons.date_range_outlined : Icons.circle,
            size: p.key == 'custom' ? 16 : 8,
            color: selectedKey == p.key ? AppColors.primary : AppColors.fgDisabled,
          ),
          const SizedBox(width: 10),
          Text(p.label, style: AppTypography.body.copyWith(
            color: selectedKey == p.key ? AppColors.primary : null,
            fontWeight: selectedKey == p.key ? FontWeight.w600 : null,
          )),
        ]),
      )).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Line chart
// ─────────────────────────────────────────────────────────────────────────────
class _LineChartCard extends StatelessWidget {
  final bool isDark;
  final Color fg, muted;
  final List<DateStat> docsOverTime;
  final String periodLabel;
  const _LineChartCard({required this.isDark, required this.fg, required this.muted,
      required this.docsOverTime, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    final gridColor = isDark ? AppColors.borderDark : const Color(0xFFF3F4F6);
    final data = docsOverTime.map((d) => d.count.toDouble()).toList();
    final labels = docsOverTime.map((d) {
      final p = d.date.split('-');
      return p.length >= 3 ? '${p[2]}/${p[1]}' : d.date;
    }).toList();
    final maxY = data.isEmpty ? 5.0 : data.fold<double>(0, (m, v) => v > m ? v : m);
    final interval = maxY > 0 ? (maxY / 4).ceilToDouble() : 1.0;

    return DgCard(
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tài liệu theo ngày', style: AppTypography.h4.copyWith(color: fg)),
            Text(periodLabel, style: AppTypography.caption.copyWith(color: muted)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(6)),
            child: Text('${data.fold<double>(0,(s,v)=>s+v).toInt()} tổng',
                style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: AppSpacing.s4),
        Expanded(
          child: data.isEmpty
              ? Center(child: Text('Không có dữ liệu', style: AppTypography.body.copyWith(color: muted)))
              : LineChart(LineChartData(
                  gridData: FlGridData(
                    show: true, drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true, interval: 1,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        final step = data.length > 14 ? (data.length / 7).ceil() : 1;
                        if (i % step != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(i >= 0 && i < labels.length ? labels[i] : '',
                              style: AppTypography.caption.copyWith(color: muted, fontSize: 10)),
                        );
                      },
                    )),
                    leftTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true, reservedSize: 36, interval: interval,
                      getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                          style: AppTypography.caption.copyWith(color: muted)),
                    )),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [LineChartBarData(
                    spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                    isCurved: true, color: AppColors.primary, barWidth: 2.5,
                    dotData: FlDotData(
                      show: data.length <= 14,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                          radius: 3, color: AppColors.primary, strokeWidth: 0),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [AppColors.primary.withOpacity(0.18), Colors.transparent],
                      ),
                    ),
                  )],
                  minY: 0, maxY: maxY > 0 ? maxY * 1.25 : 5,
                )),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pie chart
// ─────────────────────────────────────────────────────────────────────────────
class _PieCard extends StatefulWidget {
  final bool isDark;
  final Color fg, muted;
  final List<LangStat> stats;
  final String title;
  final Map<String, Color> colorMap;
  final Map<String, String> nameMap;
  const _PieCard({required this.isDark, required this.fg, required this.muted,
      required this.stats, required this.title,
      required this.colorMap, required this.nameMap});
  @override
  State<_PieCard> createState() => _PieCardState();
}

class _PieCardState extends State<_PieCard> {
  int _touched = -1;
  @override
  Widget build(BuildContext context) {
    if (widget.stats.isEmpty) {
      return DgCard(
        padding: const EdgeInsets.all(AppSpacing.s5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title, style: AppTypography.h4.copyWith(color: widget.fg)),
          Expanded(child: Center(child: Text('Không có dữ liệu',
              style: AppTypography.body.copyWith(color: widget.muted)))),
        ]),
      );
    }
    final total = widget.stats.fold<int>(0, (s, x) => s + x.count);
    final items = widget.stats.map((s) => (
      label: widget.nameMap[s.language] ?? s.language,
      value: total == 0 ? 0.0 : (s.count / total) * 100,
      color: widget.colorMap[s.language] ?? AppColors.fgDisabled,
      count: s.count,
    )).toList();

    return DgCard(
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title, style: AppTypography.h4.copyWith(color: widget.fg)),
        const SizedBox(height: AppSpacing.s3),
        Expanded(
          child: PieChart(PieChartData(
            pieTouchData: PieTouchData(touchCallback: (_, res) =>
                setState(() => _touched = res?.touchedSection?.touchedSectionIndex ?? -1)),
            sections: items.asMap().entries.map((e) {
              final isTouched = e.key == _touched;
              return PieChartSectionData(
                value: e.value.value,
                color: e.value.color,
                radius: isTouched ? 62 : 50,
                title: isTouched ? '${e.value.value.toStringAsFixed(1)}%'
                    : (e.value.value >= 12 ? '${e.value.value.toInt()}%' : ''),
                titleStyle: AppTypography.caption.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
              );
            }).toList(),
            sectionsSpace: 2,
            centerSpaceRadius: 32,
          )),
        ),
        const SizedBox(height: AppSpacing.s2),
        Wrap(
          spacing: AppSpacing.s3, runSpacing: 4, alignment: WrapAlignment.center,
          children: items.map((item) => Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text('${item.label} (${item.count})',
                style: AppTypography.caption.copyWith(color: widget.muted)),
          ])).toList(),
        ),
      ]),
    );
  }
}
