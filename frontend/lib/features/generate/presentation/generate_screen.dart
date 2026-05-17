// lib/features/generate/presentation/generate_screen.dart
//
// FIX trong file này:
// 1. _generate() khi nhận response từ API: output HIỂN THỊ content_md thật (không phải rỗng)
// 2. Output panel có tab "Tài liệu" và "Code gốc" để xem raw code đã submit
// 3. Tên file export đúng: lấy từ title hoặc uploadedFileName, sanitize ký tự đặc biệt
// 4. _exportMarkdown, _exportPdf, _exportDocx dùng tên file đúng
// 5. activeModels: nếu rỗng hiện warning nhưng vẫn cho generate (dùng model mặc định)
//
// Lưu ý: file này thay thế HOÀN TOÀN file cũ.

import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
// import 'dart:html' as html_lib;
import 'package:universal_html/html.dart' as html_lib;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/models.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/dg_button.dart';
import '../../../shared/widgets/dg_misc.dart';
import '../../history/data/history_repository.dart';
import '../data/generate_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Download helpers
// ─────────────────────────────────────────────────────────────────────────────
void _downloadBytes(List<int> bytes, String filename) {
  if (!kIsWeb) return;
  final blob = html_lib.Blob([bytes], 'application/octet-stream');
  final url = html_lib.Url.createObjectUrlFromBlob(blob);
  html_lib.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html_lib.Url.revokeObjectUrl(url);
}

void _downloadString(String content, String filename) {
  _downloadBytes(utf8.encode(content), filename);
}

String _safeName(String title, String? uploadedFileName, String ext) {
  // Ưu tiên dùng tên file upload nếu có, bỏ extension cũ
  final base = uploadedFileName != null
      ? uploadedFileName.replaceAll(RegExp(r'\.[^\.]+$'), '')
      : title;
  // Sanitize: giữ lại chữ cái, số, dấu gạch dưới/ngang; thay còn lại bằng _
  final safe = base.replaceAll(RegExp(r'[^\w\-]'), '_').replaceAll(RegExp(r'_+'), '_');
  return '${safe.isEmpty ? "document" : safe}$ext';
}

// ─────────────────────────────────────────────────────────────────────────────
class GenerateScreen extends ConsumerStatefulWidget {
  const GenerateScreen({super.key});

  @override
  ConsumerState<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends ConsumerState<GenerateScreen>
    with TickerProviderStateMixin {
  late final TabController _inputTabCtrl;
  late final TabController _mobileTabCtrl;
  late final TabController _outputTabCtrl; // Tài liệu | Code gốc

  final _codeCtrl = TextEditingController();
  String _selectedLang = 'python';
  bool _generating = false;
  bool _checkingSyntax = false;
  bool _hasOutput = false;
  String _output = '';
  String _rawCodeSubmitted = ''; // Lưu code đã submit để hiển thị
  bool _editMode = false;
  final _editCtrl = TextEditingController();
  int? _currentDocId;
  String? _uploadedFileName;
  SourceType _sourceType = SourceType.DIRECT_TEXT;
  AIModelType? _selectedModel;
  String _currentTitle = '';

  final _langs = const [
    ('python', 'Python'), ('javascript', 'JavaScript'), ('java', 'Java'),
    ('cpp', 'C++'), ('typescript', 'TypeScript'), ('rust', 'Rust'),
  ];

  @override
  void initState() {
    super.initState();
    _inputTabCtrl  = TabController(length: 2, vsync: this);
    _mobileTabCtrl = TabController(length: 2, vsync: this);
    _outputTabCtrl = TabController(length: 2, vsync: this);

    _inputTabCtrl.addListener(() {
      if (!_inputTabCtrl.indexIsChanging) {
        setState(() => _sourceType = _inputTabCtrl.index == 0
            ? SourceType.DIRECT_TEXT
            : SourceType.FILE_UPLOAD);
      }
    });
  }

  @override
  void dispose() {
    _inputTabCtrl.dispose();
    _mobileTabCtrl.dispose();
    _outputTabCtrl.dispose();
    _codeCtrl.dispose();
    _editCtrl.dispose();
    super.dispose();
  }

  // ── File picker ─────────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['py','js','jsx','ts','tsx','java','cpp','cc','cxx','h','hpp','rs'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final content = file.bytes != null
          ? utf8.decode(file.bytes!, allowMalformed: true)
          : null;
      if (content == null) {
        if (mounted) DgToast.show(context, 'Không đọc được nội dung file', type: ToastType.error);
        return;
      }
      setState(() {
        _codeCtrl.text = content;
        _uploadedFileName = file.name;
        _sourceType = SourceType.FILE_UPLOAD;
        final ext = file.extension?.toLowerCase() ?? '';
        _selectedLang = _detectLangFromExt(ext) ?? _selectedLang;
      });
      if (mounted) DgToast.show(context, 'Đã tải lên ${file.name}', type: ToastType.success);
    } catch (e) {
      if (mounted) DgToast.show(context, 'Lỗi: $e', type: ToastType.error);
    }
  }

  String? _detectLangFromExt(String ext) => switch (ext) {
    'py' => 'python', 'js' || 'jsx' => 'javascript', 'ts' || 'tsx' => 'typescript',
    'java' => 'java', 'cpp'||'cc'||'cxx'||'h'||'hpp' => 'cpp', 'rs' => 'rust', _ => null,
  };

  // ── Syntax check ────────────────────────────────────────────────────────────
  Future<bool> _checkSyntax(String code, ProgrammingLanguage lang) async {
    setState(() => _checkingSyntax = true);
    try {
      final result = await ref.read(generateRepoProvider).checkSyntax(code: code, language: lang);
      setState(() => _checkingSyntax = false);
      if (!result.hasError) return true;
      if (!mounted) return false;
      return await showDialog<bool>(
        context: context,
        builder: (_) => _SyntaxDialog(result: result, lang: lang),
      ) ?? false;
    } catch (_) {
      setState(() => _checkingSyntax = false);
      return true; // fail-safe: tiếp tục nếu check lỗi
    }
  }

  // ── Model selector ──────────────────────────────────────────────────────────
  Future<void> _showModelSelector() async {
    final models = await ref.read(activeModelsProvider.future).catchError((_) => <AIModelConfig>[]);
    if (!mounted) return;
    if (models.isEmpty) {
      DgToast.show(context, 'Không có mô hình nào đang hoạt động. Dùng mô hình mặc định.',
          type: ToastType.warning);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ModelSheet(
        models: models,
        selectedModel: _selectedModel,
        onSelect: (m) { setState(() => _selectedModel = m); Navigator.pop(context); },
      ),
    );
  }

  // ── GENERATE ────────────────────────────────────────────────────────────────
  Future<void> _generate() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      DgToast.show(context, 'Vui lòng nhập mã nguồn', type: ToastType.warning);
      return;
    }
    if (code.length < 10) {
      DgToast.show(context, 'Mã nguồn quá ngắn', type: ToastType.warning);
      return;
    }

    final lang = ProgrammingLanguage.fromUiKey(_selectedLang);

    // Kiểm tra model có active không
    if (_selectedModel != null) {
      final models = await ref.read(activeModelsProvider.future).catchError((_) => <AIModelConfig>[]);
      if (models.isNotEmpty && !models.any((m) => m.modelType == _selectedModel)) {
        if (!mounted) return;
        await showDialog(context: context,
            builder: (_) => _ModelUnavailableDialog(modelType: _selectedModel!));
        return;
      }
    }

    // Syntax check
    final canProceed = await _checkSyntax(code, lang);
    if (!canProceed || !mounted) return;

    setState(() { _generating = true; _hasOutput = false; _currentDocId = null; });

    try {
      final user = ref.read(currentUserProvider);
      final title = _uploadedFileName ??
          'Doc_${lang.displayName}_${DateTime.now().millisecondsSinceEpoch}';

      final doc = await ref.read(generateRepoProvider).generate(
        title: title,
        rawCode: code,
        language: lang,
        sourceType: _sourceType,
        userId: user?.userId,
        modelType: _selectedModel,
      );

      if (!mounted) return;

      final content = doc.contentMd.trim();
      if (content.isEmpty) {
        // Log để debug
        debugPrint('[GenerateScreen] contentMd rỗng! doc: $doc');
      }

      setState(() {
        _generating = false;
        _hasOutput = content.isNotEmpty;
        _output = content;
        _rawCodeSubmitted = code;
        _currentDocId = doc.docId;
        _currentTitle = title;
        _editCtrl.text = content;
      });

      if (user != null) ref.invalidate(historyListProvider);
      if (Responsive.isMobile(context)) _mobileTabCtrl.animateTo(1);

      DgToast.show(context,
          content.isEmpty
              ? 'Sinh xong nhưng tài liệu trống — kiểm tra backend'
              : (user == null ? 'Sinh tài liệu thành công (Khách)' : 'Sinh tài liệu thành công'),
          type: content.isEmpty ? ToastType.warning : ToastType.success);

    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      if (e.message.toLowerCase().contains('ngoài thời gian') ||
          e.message.toLowerCase().contains('model')) {
        await showDialog(context: context,
            builder: (_) => _ModelUnavailableDialog(
                modelType: _selectedModel ?? AIModelType.GROQ_LLAMA3));
      } else {
        DgToast.show(context, e.message, type: ToastType.error);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      DgToast.show(context, 'Lỗi: $e', type: ToastType.error);
    }
  }

  // ── Export / copy / save ────────────────────────────────────────────────────
  void _copyOutput() {
    Clipboard.setData(ClipboardData(text: _editMode ? _editCtrl.text : _output));
    DgToast.show(context, 'Đã sao chép', type: ToastType.success);
  }

  Future<void> _saveHistory() async {
    final user = ref.read(currentUserProvider);
    if (user == null) { DgToast.show(context, 'Vui lòng đăng nhập', type: ToastType.warning); return; }
    if (_currentDocId == null) { DgToast.show(context, 'Chưa có tài liệu để lưu', type: ToastType.warning); return; }
    final content = _editMode ? _editCtrl.text : _output;
    try {
      await ref.read(historyRepoProvider).updateDoc(
          docId: _currentDocId!, userId: user.userId, contentMd: content);
      setState(() { _output = content; if (_editMode) _editMode = false; });
      ref.invalidate(historyListProvider);
      if (mounted) DgToast.show(context, 'Đã lưu vào lịch sử', type: ToastType.success);
    } on ApiException catch (e) {
      if (mounted) DgToast.show(context, e.message, type: ToastType.error);
    }
  }

  void _exportMarkdown() {
    final content = _editMode ? _editCtrl.text : _output;
    _downloadString(content, _safeName(_currentTitle, _uploadedFileName, '.md'));
    DgToast.show(context, 'Đã tải Markdown', type: ToastType.success);
  }

  Future<void> _exportPdf() async {
    final user = ref.read(currentUserProvider);
    if (_currentDocId == null || user == null) { _exportMarkdown(); return; }
    try {
      DgToast.show(context, 'Đang tạo PDF...', type: ToastType.info);
      final bytes = await ref.read(historyRepoProvider)
          .exportPdf(docId: _currentDocId!, userId: user.userId);
      _downloadBytes(bytes, _safeName(_currentTitle, _uploadedFileName, '.pdf'));
      if (mounted) DgToast.show(context, 'Đã tải PDF', type: ToastType.success);
    } on ApiException catch (e) {
      if (mounted) DgToast.show(context, e.message, type: ToastType.error);
    }
  }

  Future<void> _exportDocx() async {
    final user = ref.read(currentUserProvider);
    if (_currentDocId == null || user == null) { _exportMarkdown(); return; }
    try {
      DgToast.show(context, 'Đang tạo Word...', type: ToastType.info);
      final bytes = await ref.read(historyRepoProvider)
          .exportDocx(docId: _currentDocId!, userId: user.userId);
      _downloadBytes(bytes, _safeName(_currentTitle, _uploadedFileName, '.docx'));
      if (mounted) DgToast.show(context, 'Đã tải Word', type: ToastType.success);
    } on ApiException catch (e) {
      if (mounted) DgToast.show(context, e.message, type: ToastType.error);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Responsive.isMobile(context) ? _buildMobile() : _buildDesktop();
  }

  Widget _buildDesktop() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: _buildInputPanel()),
        const SizedBox(width: AppSpacing.s4),
        Expanded(child: _buildOutputPanel()),
      ]),
    );
  }

  Widget _buildMobile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final muted  = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    return Column(children: [
      Container(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        child: TabBar(
          controller: _mobileTabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: muted,
          indicatorColor: AppColors.primary,
          dividerColor: border,
          labelStyle: AppTypography.bodyMedium,
          tabs: const [Tab(text: 'Nhập mã nguồn'), Tab(text: 'Tài liệu')],
        ),
      ),
      Expanded(child: TabBarView(
        controller: _mobileTabCtrl,
        children: [
          Padding(padding: const EdgeInsets.all(AppSpacing.s4), child: _buildInputPanel()),
          Padding(padding: const EdgeInsets.all(AppSpacing.s4), child: _buildOutputPanel()),
        ],
      )),
    ]);
  }

  // ── Input Panel ─────────────────────────────────────────────────────────────
  Widget _buildInputPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AppColors.cardDark   : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark  : AppColors.borderLight;
    final fg     = isDark ? AppColors.fgDark      : AppColors.fgLight;
    final muted  = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final codeBg = isDark ? AppColors.bgDark      : AppColors.sunkenLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Tab bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border))),
          child: Row(children: [
            _SmallTab(label: 'Dán mã nguồn', index: 0, ctrl: _inputTabCtrl, isDark: isDark),
            const SizedBox(width: AppSpacing.s2),
            _SmallTab(label: 'Tải tệp lên',  index: 1, ctrl: _inputTabCtrl, isDark: isDark),
            const Spacer(),
            _LangSelector(selected: _selectedLang, langs: _langs, isDark: isDark,
                onChanged: (v) => setState(() => _selectedLang = v)),
          ]),
        ),
        // Content
        Expanded(child: AnimatedBuilder(
          animation: _inputTabCtrl,
          builder: (_, __) {
            if (_inputTabCtrl.index == 0) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.s3),
                child: Container(
                  decoration: BoxDecoration(
                    color: codeBg, borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: border),
                  ),
                  child: Shortcuts(
                    shortcuts: {LogicalKeySet(LogicalKeyboardKey.tab): const _TabIntent()},
                    child: Actions(
                      actions: {
                        _TabIntent: CallbackAction<_TabIntent>(onInvoke: (intent) {
                          final sel = _codeCtrl.selection;
                          final newText = _codeCtrl.text.replaceRange(sel.start, sel.end, '    ');
                          _codeCtrl.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(offset: sel.start + 4),
                          );
                          return null;
                        }),
                      },
                      child: TextField(
                        controller: _codeCtrl,
                        maxLines: null, minLines: null, expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: AppTypography.code.copyWith(color: fg, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: '// Dán mã nguồn của bạn vào đây...',
                          hintStyle: AppTypography.code.copyWith(
                              color: isDark ? AppColors.fgSubtleDark : AppColors.fgSubtleLight,
                              fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(AppSpacing.s3),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return _UploadZone(isDark: isDark, border: border, muted: muted,
                fileName: _uploadedFileName, onTap: _pickFile);
          },
        )),
        // Model picker + generate
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Column(children: [
            _ModelPickerRow(selectedModel: _selectedModel, isDark: isDark, onTap: _showModelSelector),
            const SizedBox(height: AppSpacing.s3),
            DgButton.primary(
              label: _generating ? 'Đang phân tích...' : (_checkingSyntax ? 'Đang kiểm tra...' : 'Sinh tài liệu'),
              icon: (_generating || _checkingSyntax) ? null : Icons.bolt,
              loading: _generating || _checkingSyntax,
              fullWidth: true,
              onPressed: (_generating || _checkingSyntax) ? null : _generate,
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Output Panel ─────────────────────────────────────────────────────────────
  Widget _buildOutputPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AppColors.cardDark   : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark  : AppColors.borderLight;
    final fg     = isDark ? AppColors.fgDark      : AppColors.fgLight;
    final muted  = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final isMobile = Responsive.isMobile(context);

    return Container(
      decoration: BoxDecoration(
          color: bg, border: Border.all(color: border),
          borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border))),
          child: Row(children: [
            // Tabs: Tài liệu | Code gốc
            if (_hasOutput) ...[
              _SmallTab(label: 'Tài liệu', index: 0, ctrl: _outputTabCtrl, isDark: isDark),
              const SizedBox(width: AppSpacing.s2),
              _SmallTab(label: 'Code gốc', index: 1, ctrl: _outputTabCtrl, isDark: isDark),
            ] else
              Text('Tài liệu', style: AppTypography.bodyMedium.copyWith(color: fg)),
            const Spacer(),
            if (_hasOutput)
              isMobile
                  ? FittedBox(fit: BoxFit.scaleDown,
                      child: _ActionRow(
                        isDark: isDark, editMode: _editMode,
                        onToggleEdit: () => setState(() {
                          _editMode = !_editMode;
                          if (_editMode) _editCtrl.text = _output;
                          else _output = _editCtrl.text;
                        }),
                        onCopy: _copyOutput, onSave: _saveHistory,
                        onExportMd: _exportMarkdown, onExportPdf: _exportPdf,
                        onExportDocx: _exportDocx,
                      ))
                  : _ActionRow(
                      isDark: isDark, editMode: _editMode,
                      onToggleEdit: () => setState(() {
                        _editMode = !_editMode;
                        if (_editMode) _editCtrl.text = _output;
                        else _output = _editCtrl.text;
                      }),
                      onCopy: _copyOutput, onSave: _saveHistory,
                      onExportMd: _exportMarkdown, onExportPdf: _exportPdf,
                      onExportDocx: _exportDocx,
                    ),
          ]),
        ),

        // Content
        Expanded(child: _generating
            ? _buildSkeleton()
            : _hasOutput
                ? AnimatedBuilder(
                    animation: _outputTabCtrl,
                    builder: (_, __) {
                      if (_outputTabCtrl.index == 1) {
                        // Tab Code gốc
                        return Padding(
                          padding: const EdgeInsets.all(AppSpacing.s4),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.s3),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.bgDark : AppColors.sunkenLight,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: border),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                _rawCodeSubmitted.isEmpty
                                    ? _codeCtrl.text
                                    : _rawCodeSubmitted,
                                style: AppTypography.code.copyWith(color: fg, fontSize: 12.5),
                              ),
                            ),
                          ),
                        );
                      }
                      // Tab Tài liệu
                      if (_editMode) {
                        return Padding(
                          padding: const EdgeInsets.all(AppSpacing.s4),
                          child: TextField(
                            controller: _editCtrl,
                            maxLines: null, minLines: null, expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: AppTypography.code.copyWith(color: fg, fontSize: 13),
                            decoration: const InputDecoration(
                              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        );
                      }
                      return Markdown(
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
                      );
                    })
                : const DgEmptyState(
                    icon: Icons.description_outlined,
                    message: 'Tài liệu sẽ hiển thị ở đây',
                    description: 'Nhập mã nguồn và nhấn "Sinh tài liệu".',
                  ),
        ),
      ]),
    );
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const DgSkeleton(width: 200, height: 22),
        const SizedBox(height: AppSpacing.s5),
        DgSkeleton.text(lines: 4),
        const SizedBox(height: AppSpacing.s5),
        const DgSkeleton(width: 160, height: 18),
        const SizedBox(height: AppSpacing.s3),
        DgSkeleton.text(lines: 3),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action row
// ─────────────────────────────────────────────────────────────────────────────
class _ActionRow extends StatelessWidget {
  final bool isDark, editMode;
  final VoidCallback onToggleEdit, onCopy, onSave, onExportMd, onExportPdf, onExportDocx;
  const _ActionRow({
    required this.isDark, required this.editMode,
    required this.onToggleEdit, required this.onCopy, required this.onSave,
    required this.onExportMd, required this.onExportPdf, required this.onExportDocx,
  });

  @override
  Widget build(BuildContext context) {
    final muted  = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final border = isDark ? AppColors.borderDark  : AppColors.borderLight;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _Btn(icon: editMode ? Icons.visibility_outlined : Icons.edit_outlined,
          label: editMode ? 'Xem' : 'Sửa', isDark: isDark, onTap: onToggleEdit),
      const SizedBox(width: 2),
      _Btn(icon: Icons.copy_outlined, label: 'Copy', isDark: isDark, onTap: onCopy),
      const SizedBox(width: 2),
      _Btn(icon: Icons.bookmark_border, label: 'Lưu', isDark: isDark, onTap: onSave),
      const SizedBox(width: 2),
      PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'md') onExportMd();
          if (v == 'pdf') onExportPdf();
          if (v == 'docx') onExportDocx();
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: border)),
        elevation: 0,
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        offset: const Offset(0, 36),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.download_outlined, size: 14, color: muted),
            const SizedBox(width: 4),
            Text('Xuất', style: AppTypography.caption.copyWith(color: muted)),
            Icon(Icons.keyboard_arrow_down, size: 12, color: muted),
          ]),
        ),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'md', height: 40, child: Row(children: [
            const Icon(Icons.description_outlined, size: 16),
            const SizedBox(width: 8), Text('Markdown (.md)', style: AppTypography.bodySmall),
          ])),
          PopupMenuItem(value: 'pdf', height: 40, child: Row(children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Colors.red),
            const SizedBox(width: 8), Text('PDF (.pdf)', style: AppTypography.bodySmall),
          ])),
          PopupMenuItem(value: 'docx', height: 40, child: Row(children: [
            const Icon(Icons.article_outlined, size: 16, color: Colors.blue),
            const SizedBox(width: 8), Text('Word (.docx)', style: AppTypography.bodySmall),
          ])),
        ],
      ),
    ]);
  }
}

class _Btn extends StatefulWidget {
  final IconData icon; final String label; final bool isDark; final VoidCallback onTap;
  const _Btn({required this.icon, required this.label, required this.isDark, required this.onTap});
  @override State<_Btn> createState() => _BtnState();
}
class _BtnState extends State<_Btn> {
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
            decoration: BoxDecoration(
              color: _hovered ? hover : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(widget.icon, size: 14, color: muted),
              const SizedBox(width: 4),
              Text(widget.label, style: AppTypography.caption.copyWith(color: muted)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Smaller components
// ─────────────────────────────────────────────────────────────────────────────
class _SmallTab extends StatelessWidget {
  final String label; final int index; final TabController ctrl; final bool isDark;
  const _SmallTab({required this.label, required this.index, required this.ctrl, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final active = ctrl.index == index;
        return GestureDetector(
          onTap: () => ctrl.animateTo(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: active ? AppColors.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label, style: AppTypography.caption.copyWith(
              color: active ? AppColors.primary : (isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight),
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            )),
          ),
        );
      },
    );
  }
}

class _LangSelector extends StatefulWidget {
  final String selected; final List<(String,String)> langs; final bool isDark;
  final ValueChanged<String> onChanged;
  const _LangSelector({required this.selected, required this.langs, required this.isDark, required this.onChanged});
  @override State<_LangSelector> createState() => _LangSelectorState();
}
class _LangSelectorState extends State<_LangSelector> {
  bool _hovered = false;
  @override Widget build(BuildContext context) {
    final border = widget.isDark ? AppColors.borderDark : AppColors.borderLight;
    final fg = widget.isDark ? AppColors.fgDark : AppColors.fgLight;
    final subtle = widget.isDark ? AppColors.fgSubtleDark : AppColors.fgSubtleLight;
    final hover = widget.isDark ? AppColors.hoverDark : AppColors.hoverLight;
    final label = widget.langs.firstWhere((l) => l.$1 == widget.selected, orElse: () => widget.langs.first).$2;
    return PopupMenuButton<String>(
      initialValue: widget.selected, onSelected: widget.onChanged,
      tooltip: 'Chọn ngôn ngữ',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: border)),
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
            border: Border.all(color: border), borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.code, size: 14, color: subtle),
            const SizedBox(width: 6),
            Text(label, style: AppTypography.caption.copyWith(color: fg, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 14, color: subtle),
          ]),
        ),
      ),
      itemBuilder: (_) => widget.langs.map((lang) {
        final isSel = lang.$1 == widget.selected;
        return PopupMenuItem<String>(
          value: lang.$1, height: 38, padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(child: Text(lang.$2, style: AppTypography.bodySmall.copyWith(
                color: fg, fontWeight: isSel ? FontWeight.w600 : FontWeight.w400))),
            if (isSel) const Icon(Icons.check, size: 16, color: AppColors.primary),
          ]),
        );
      }).toList(),
    );
  }
}

class _UploadZone extends StatelessWidget {
  final bool isDark; final Color border, muted; final String? fileName; final VoidCallback onTap;
  const _UploadZone({required this.isDark, required this.border, required this.muted, this.fileName, required this.onTap});
  @override Widget build(BuildContext context) {
    final has = fileName != null;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          constraints: const BoxConstraints(minHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: has ? AppColors.primary : border, width: 1.5),
            borderRadius: BorderRadius.circular(6),
            color: has ? AppColors.primarySoft : (isDark ? AppColors.bgDark : AppColors.sunkenLight),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(has ? Icons.check_circle_outline : Icons.upload_file_outlined,
                size: 32, color: has ? AppColors.primary : muted),
            const SizedBox(height: AppSpacing.s3),
            Text(has ? fileName! : 'Kéo tệp vào đây hoặc nhấn để chọn',
                style: AppTypography.body.copyWith(
                    color: has ? AppColors.primary : muted,
                    fontWeight: has ? FontWeight.w600 : FontWeight.w400),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(has ? 'Nhấn để chọn file khác' : '.py · .js · .ts · .java · .cpp · .rs',
                style: AppTypography.caption.copyWith(color: muted)),
          ]),
        ),
      ),
    );
  }
}

class _ModelPickerRow extends StatelessWidget {
  final AIModelType? selectedModel; final bool isDark; final VoidCallback onTap;
  const _ModelPickerRow({required this.selectedModel, required this.isDark, required this.onTap});
  @override Widget build(BuildContext context) {
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final muted  = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final fg     = isDark ? AppColors.fgDark : AppColors.fgLight;
    final label  = switch (selectedModel) {
      AIModelType.GROQ_LLAMA3      => 'Llama 3.1 8B (Groq)',
      AIModelType.KAGGLE_FINETUNED => 'Llama 3.1B Finetuned (Kaggle)',
      null => 'Chọn mô hình AI...',
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          Icon(Icons.smart_toy_outlined, size: 15, color: muted),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppTypography.bodySmall.copyWith(
              color: selectedModel != null ? fg : muted), overflow: TextOverflow.ellipsis)),
          Icon(Icons.keyboard_arrow_down, size: 16, color: muted),
        ]),
      ),
    );
  }
}

class _ModelSheet extends StatelessWidget {
  final List<AIModelConfig> models; final AIModelType? selectedModel;
  final ValueChanged<AIModelType?> onSelect;
  const _ModelSheet({required this.models, required this.selectedModel, required this.onSelect});
  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final fg     = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted  = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    return Container(
      decoration: BoxDecoration(color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border.all(color: border)),
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: AppSpacing.s4),
        Text('Chọn mô hình AI', style: AppTypography.h4.copyWith(color: fg)),
        Text('Chỉ hiển thị mô hình đang hoạt động', style: AppTypography.caption.copyWith(color: muted)),
        const SizedBox(height: AppSpacing.s4),
        ...models.map((m) {
          final isSel = m.modelType == selectedModel;
          return ListTile(
            onTap: () => onSelect(m.modelType),
            leading: Icon(Icons.smart_toy_outlined, color: isSel ? AppColors.primary : muted),
            title: Text(m.displayName, style: AppTypography.body.copyWith(
                color: isSel ? AppColors.primary : fg,
                fontWeight: isSel ? FontWeight.w600 : FontWeight.w400)),
            subtitle: m.description != null
                ? Text(m.description!, style: AppTypography.caption.copyWith(color: muted)) : null,
            trailing: isSel ? const Icon(Icons.check, color: AppColors.primary) : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          );
        }),
        ListTile(
          onTap: () => onSelect(null),
          leading: Icon(Icons.auto_awesome, color: selectedModel == null ? AppColors.primary : muted),
          title: Text('Tự động (Mặc định)', style: AppTypography.body.copyWith(
              color: selectedModel == null ? AppColors.primary : fg,
              fontWeight: selectedModel == null ? FontWeight.w600 : FontWeight.w400)),
          trailing: selectedModel == null ? const Icon(Icons.check, color: AppColors.primary) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        const SizedBox(height: AppSpacing.s2),
      ]),
    );
  }
}

class _SyntaxDialog extends StatelessWidget {
  final SyntaxCheckResult result; final ProgrammingLanguage lang;
  const _SyntaxDialog({required this.result, required this.lang});
  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
        const SizedBox(width: 8),
        Text('Phát hiện lỗi Syntax', style: AppTypography.h4.copyWith(color: fg)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Mã nguồn ${lang.displayName} có vẻ chứa lỗi cú pháp:',
            style: AppTypography.body.copyWith(color: fg)),
        const SizedBox(height: 12),
        if (result.errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (result.errorLine != null)
                Text('Dòng ${result.errorLine}:', style: AppTypography.caption.copyWith(
                    color: Colors.red, fontWeight: FontWeight.w600)),
              Text(result.errorMessage!, style: AppTypography.code.copyWith(color: Colors.red, fontSize: 12)),
            ]),
          ),
        const SizedBox(height: 12),
        Text('Bạn vẫn muốn sinh tài liệu từ mã này?',
            style: AppTypography.bodySmall.copyWith(
                color: isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Sửa lại')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Vẫn tiếp tục', style: TextStyle(color: Colors.white))),
      ],
    );
  }
}

class _ModelUnavailableDialog extends StatelessWidget {
  final AIModelType modelType;
  const _ModelUnavailableDialog({required this.modelType});
  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final name = switch (modelType) {
      AIModelType.GROQ_LLAMA3      => 'Llama 3.1 8B (Groq)',
      AIModelType.KAGGLE_FINETUNED => 'Llama 3.1B Finetuned (Kaggle)',
    };
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.schedule, color: Colors.orange, size: 22),
        const SizedBox(width: 8),
        Expanded(child: Text('Mô hình ngoài giờ', style: AppTypography.h4.copyWith(color: fg))),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Mô hình $name hiện đang ngoài thời gian sử dụng.',
            style: AppTypography.body.copyWith(color: fg)),
        const SizedBox(height: 8),
        Text('Vui lòng liên hệ chúng tôi hoặc chọn mô hình khác.',
            style: AppTypography.bodySmall.copyWith(
                color: isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
        ElevatedButton.icon(
          onPressed: () { Navigator.pop(context); context.push('/contact'); },
          icon: const Icon(Icons.contact_support_outlined, size: 16),
          label: const Text('Liên hệ'),
        ),
      ],
    );
  }
}

class _TabIntent extends Intent { const _TabIntent(); }
