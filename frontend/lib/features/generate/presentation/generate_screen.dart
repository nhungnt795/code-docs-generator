// lib/features/generate/presentation/generate_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/dg_button.dart';
import '../../../shared/widgets/dg_misc.dart';

class GenerateScreen extends StatefulWidget {
  const GenerateScreen({super.key});

  @override
  State<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends State<GenerateScreen>
    with TickerProviderStateMixin {
  late final TabController _inputTabCtrl;
  late final TabController _mobileTabCtrl;

  final _codeCtrl = TextEditingController();
  String _selectedLang = 'python'; // Default language
  bool _generating  = false;
  bool _hasOutput   = false;
  String _output    = '';
  bool _editMode    = false;
  final _editCtrl   = TextEditingController();

  final _langs = const [
    ('python', 'Python'),
    ('javascript', 'JavaScript'),
    ('java', 'Java'),
    ('cpp', 'C++'),
    ('typescript', 'TypeScript'),
    ('rust', 'Rust'),
  ];

  final _sampleOutput = '''## `UserService`
Lớp xử lý nghiệp vụ liên quan đến người dùng.
... (Demo output)''';

  @override
  void initState() {
    super.initState();
    _inputTabCtrl  = TabController(length: 2, vsync: this);
    _mobileTabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _inputTabCtrl.dispose();
    _mobileTabCtrl.dispose();
    _codeCtrl.dispose();
    _editCtrl.dispose();
    super.dispose();
  }

  Future _generate() async {
    if (_codeCtrl.text.trim().isEmpty) {
      DgToast.show(context, 'Vui lòng nhập mã nguồn trước', type: ToastType.warning);
      return;
    }

    setState(() { _generating = true; _hasOutput = false; });
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() {
      _generating = false;
      _hasOutput  = true;
      _output     = _sampleOutput;
    });

    if (mounted && Responsive.isMobile(context)) {
      _mobileTabCtrl.animateTo(1);
    }
  }

  void _copyOutput() {
    Clipboard.setData(ClipboardData(text: _output));
    DgToast.show(context, 'Đã sao chép vào clipboard', type: ToastType.success);
  }

  Future _saveHistory() async {
    DgToast.show(context, 'Đã lưu tài liệu vào lịch sử thành công', type: ToastType.success);
  }

  void _exportMarkdown() {
    DgToast.show(context, 'Tính năng xuất file MD đang phát triển', type: ToastType.info);
  }

  void _exportPdf() {
    DgToast.show(context, 'Tính năng xuất PDF đang phát triển', type: ToastType.info);
  }

  @override
  Widget build(BuildContext context) {
    return Responsive.isMobile(context)
        ? _buildMobile()
        : _buildDesktop();
  }

  Widget _buildDesktop() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _InputPanel()),
          const SizedBox(width: AppSpacing.s4),
          Expanded(child: _OutputPanel()),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final muted  = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          child: TabBar(
            controller: _mobileTabCtrl,
            labelColor: AppColors.primary,
            unselectedLabelColor: muted,
            indicatorColor: AppColors.primary,
            dividerColor: border,
            labelStyle: AppTypography.bodyMedium,
            tabs: const [
              Tab(text: 'Nhập mã nguồn'),
              Tab(text: 'Tài liệu'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _mobileTabCtrl,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: _InputPanel(),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: _OutputPanel(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _InputPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AppColors.cardDark    : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark  : AppColors.borderLight;
    final fg     = isDark ? AppColors.fgDark      : AppColors.fgLight;
    final muted  = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final codeBg = isDark ? AppColors.bgDark      : AppColors.sunkenLight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s4, vertical: 10,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                _SmallTab(
                  label: 'Dán mã nguồn',
                  index: 0,
                  controller: _inputTabCtrl,
                  isDark: isDark,
                ),
                const SizedBox(width: AppSpacing.s2),
                _SmallTab(
                  label: 'Tải tệp lên',
                  index: 1,
                  controller: _inputTabCtrl,
                  isDark: isDark,
                ),
                const Spacer(),
                // Sử dụng component chọn ngôn ngữ mới mượt mà hơn
                _LanguageSelector(
                  selectedLang: _selectedLang,
                  langs: _langs,
                  onChanged: (v) => setState(() => _selectedLang = v),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _inputTabCtrl,
              builder: (_, __) {
                if (_inputTabCtrl.index == 0) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.s3),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        color: codeBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: border),
                      ),
                      child: TextField(
                        controller: _codeCtrl,
                        maxLines: null,
                        minLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: AppTypography.code.copyWith(
                          color: fg, fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: '// Dán mã nguồn của bạn vào đây...',
                          hintStyle: AppTypography.code.copyWith(
                            color: isDark ? AppColors.fgSubtleDark : AppColors.fgSubtleLight,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.all(AppSpacing.s3),
                          isDense: true,
                        ),
                      ),
                    ),
                  );
                }
                return _UploadZone(isDark: isDark, border: border, muted: muted);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: DgButton.primary(
              label: _generating ? 'Đang phân tích...' : 'Sinh tài liệu',
              icon: _generating ? null : Icons.bolt,
              loading: _generating,
              fullWidth: true,
              onPressed: _generating ? null : _generate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _OutputPanel() {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final bg       = isDark ? AppColors.cardDark   : AppColors.cardLight;
    final border   = isDark ? AppColors.borderDark : AppColors.borderLight;
    final fg       = isDark ? AppColors.fgDark     : AppColors.fgLight;
    final isMobile = Responsive.isMobile(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s4, vertical: 10,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                if (!isMobile) ...[
                  Text(
                    'Tài liệu',
                    style: AppTypography.bodyMedium.copyWith(color: fg),
                  ),
                  const SizedBox(width: AppSpacing.s4),
                ],

                if (_hasOutput)
                  Expanded(
                    child: isMobile
                    // Ép vừa khung hình, nếu tràn sẽ tự động thu nhỏ một chút để fit màn hình
                        ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min, // Giữ các nút sát nhau để căn giữa
                        children: [
                          _ActionBtn(
                            icon: _editMode ? Icons.visibility_outlined : Icons.edit_outlined,
                            label: _editMode ? 'Xem' : 'Chỉnh sửa',
                            onTap: () {
                              setState(() {
                                _editMode = !_editMode;
                                if (_editMode) _editCtrl.text = _output;
                                else _output = _editCtrl.text;
                              });
                            },
                            isDark: isDark,
                          ),
                          const SizedBox(width: 4),
                          _ActionBtn(
                            icon: Icons.copy_outlined,
                            label: 'Sao chép',
                            onTap: _copyOutput,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 4),
                          _ActionBtn(
                            icon: Icons.bookmark_border,
                            label: 'Lưu',
                            onTap: _saveHistory,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 4),
                          _ExportMenu(
                            onExportMd:  _exportMarkdown,
                            onExportPdf: _exportPdf,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    )
                        : Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ActionBtn(
                            icon: _editMode ? Icons.visibility_outlined : Icons.edit_outlined,
                            label: _editMode ? 'Xem' : 'Chỉnh sửa',
                            onTap: () {
                              setState(() {
                                _editMode = !_editMode;
                                if (_editMode) _editCtrl.text = _output;
                                else _output = _editCtrl.text;
                              });
                            },
                            isDark: isDark,
                          ),
                          const SizedBox(width: 4),
                          _ActionBtn(
                            icon: Icons.copy_outlined,
                            label: 'Sao chép',
                            onTap: _copyOutput,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 4),
                          _ActionBtn(
                            icon: Icons.bookmark_border,
                            label: 'Lưu',
                            onTap: _saveHistory,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 4),
                          _ExportMenu(
                            onExportMd:  _exportMarkdown,
                            onExportPdf: _exportPdf,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: _generating
                ? _buildSkeletonOutput()
                : _hasOutput
                ? _editMode
                ? Padding(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: TextField(
                controller: _editCtrl,
                maxLines: null,
                minLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: AppTypography.code.copyWith(
                  color: fg, fontSize: 13,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            )
                : Markdown(
              data: _output,
              padding: const EdgeInsets.all(AppSpacing.s5),
              styleSheet: MarkdownStyleSheet(
                p: AppTypography.body.copyWith(color: fg),
                h1: AppTypography.h2.copyWith(color: fg),
                h2: AppTypography.h3.copyWith(color: fg),
                h3: AppTypography.h4.copyWith(color: fg),
                code: AppTypography.code.copyWith(color: fg),
                codeblockDecoration: BoxDecoration(
                  color: isDark ? AppColors.bgDark : AppColors.sunkenLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: border),
                ),
              ),
            )
                : const DgEmptyState(
              icon: Icons.description_outlined,
              message: 'Tài liệu sẽ hiển thị ở đây',
              description: 'Nhập mã nguồn và nhấn "Sinh tài liệu" để bắt đầu.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonOutput() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DgSkeleton(width: 200, height: 22),
          const SizedBox(height: AppSpacing.s5),
          DgSkeleton.text(lines: 4),
          const SizedBox(height: AppSpacing.s5),
          const DgSkeleton(width: 160, height: 18),
          const SizedBox(height: AppSpacing.s3),
          DgSkeleton.text(lines: 3),
          const SizedBox(height: AppSpacing.s5),
          const DgSkeleton(width: 180, height: 18),
          const SizedBox(height: AppSpacing.s3),
          DgSkeleton.text(lines: 5),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Component Tùy chỉnh ngôn ngữ mới
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Component Tùy chỉnh ngôn ngữ
// ─────────────────────────────────────────────────────────────────────────────
class _LanguageSelector extends StatefulWidget {
  final String selectedLang;
  final List<(String, String)> langs;
  final ValueChanged<String> onChanged;
  final bool isDark;

  const _LanguageSelector({
    required this.selectedLang,
    required this.langs,
    required this.onChanged,
    required this.isDark,
  });

  @override
  State<_LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<_LanguageSelector> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final border = widget.isDark ? AppColors.borderDark : AppColors.borderLight;
    final fg     = widget.isDark ? AppColors.fgDark : AppColors.fgLight;
    final hover  = widget.isDark ? AppColors.hoverDark : AppColors.hoverLight;
    final subtle = widget.isDark ? AppColors.fgSubtleDark : AppColors.fgSubtleLight;

    // Tìm nhãn hiển thị của ngôn ngữ hiện tại
    final selectedLabel = widget.langs
        .firstWhere((l) => l.$1 == widget.selectedLang, orElse: () => widget.langs.first).$2;

    return PopupMenuButton<String>(
      initialValue: widget.selectedLang,
      onSelected: widget.onChanged,
      tooltip: 'Chọn ngôn ngữ',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: border),
      ),
      elevation: 0,
      color: widget.isDark ? AppColors.cardDark : AppColors.cardLight,
      offset: const Offset(0, 42),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? hover : Colors.transparent,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.code, size: 14, color: subtle),
              const SizedBox(width: 6),
              Text(
                selectedLabel,
                style: AppTypography.caption.copyWith(color: fg, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, size: 14, color: subtle),
            ],
          ),
        ),
      ),
      itemBuilder: (context) {
        return widget.langs.map((lang) {
          final isSelected = lang.$1 == widget.selectedLang;
          return PopupMenuItem<String>(
            value: lang.$1,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lang.$2,
                    style: AppTypography.bodySmall.copyWith(
                      // Sửa lỗi tương phản: Chỉ in đậm, giữ màu chữ cơ bản để dễ đọc
                      color: fg,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check,
                    size: 16,
                    // Làm sáng màu checkmark trên nền tối để đồng bộ với thẻ hover
                    color: widget.isDark ? const Color(0xFF818CF8) : AppColors.primary,
                  ),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Các Component Phụ Trợ
// ─────────────────────────────────────────────────────────────────────────────

class _SmallTab extends StatelessWidget {
  final String label;
  final int index;
  final TabController controller;
  final bool isDark;
  const _SmallTab({required this.label, required this.index, required this.controller, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final active = controller.index == index;
        return GestureDetector(
          onTap: () => controller.animateTo(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: active ? AppColors.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: active ? AppColors.primary : (isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight),
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UploadZone extends StatelessWidget {
  final bool isDark;
  final Color border;
  final Color muted;
  const _UploadZone({required this.isDark, required this.border, required this.muted});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: GestureDetector(
        onTap: () => DgToast.show(context, 'Tính năng tải tệp đang phát triển', type: ToastType.info),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          constraints: const BoxConstraints(minHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 1.5),
            borderRadius: BorderRadius.circular(6),
            color: isDark ? AppColors.bgDark : AppColors.sunkenLight,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file_outlined, size: 32, color: muted),
              const SizedBox(height: AppSpacing.s3),
              Text('Kéo tệp vào đây hoặc nhấn để chọn', style: AppTypography.body.copyWith(color: muted)),
              const SizedBox(height: 4),
              Text('.py · .js · .ts · .java · .cpp · .rs', style: AppTypography.caption.copyWith(color: muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  const _ActionBtn({required this.icon, required this.label, required this.onTap, required this.isDark});
  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final hover = widget.isDark ? AppColors.hoverDark : AppColors.hoverLight;
    final muted = widget.isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    return Tooltip(
      message: widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: _hovered ? hover : Colors.transparent, borderRadius: BorderRadius.circular(6)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 14, color: muted),
                const SizedBox(width: 4),
                Text(widget.label, style: AppTypography.caption.copyWith(color: muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExportMenu extends StatelessWidget {
  final VoidCallback onExportMd;
  final VoidCallback onExportPdf;
  final bool isDark;

  const _ExportMenu({
    required this.onExportMd,
    required this.onExportPdf,
    required this.isDark
  });

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final hover = isDark ? AppColors.hoverDark : AppColors.hoverLight;

    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'md')  onExportMd();
        if (v == 'pdf') onExportPdf();
      },
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border)
      ),
      elevation: 0,
      color: isDark ? AppColors.cardDark : AppColors.cardLight,
      // Thêm offset để đẩy menu xuống dưới viền nút
      offset: const Offset(0, 36),
      child: StatefulBuilder(
          builder: (context, setState) {
            bool isHovered = false;
            return MouseRegion(
              onEnter: (_) => setState(() => isHovered = true),
              onExit:  (_) => setState(() => isHovered = false),
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isHovered ? hover : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download_outlined, size: 14, color: muted),
                    const SizedBox(width: 4),
                    Text('Xuất file', style: AppTypography.caption.copyWith(color: muted)),
                    const SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down, size: 12, color: muted),
                  ],
                ),
              ),
            );
          }
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
            value: 'md',
            height: 40,
            child: Row(
                children: [
                  const Icon(Icons.description_outlined, size: 16),
                  const SizedBox(width: 8),
                  Text('Xuất Markdown', style: AppTypography.bodySmall)
                ]
            )
        ),
        PopupMenuItem(
            value: 'pdf',
            height: 40,
            child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  const SizedBox(width: 8),
                  Text('Xuất PDF', style: AppTypography.bodySmall)
                ]
            )
        ),
      ],
    );
  }
}