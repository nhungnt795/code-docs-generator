// lib/core/api/models.dart
// ─────────────────────────────────────────────────────────────────────────────
// Mirror các Pydantic schemas bên Python sang Dart class
// ─────────────────────────────────────────────────────────────────────────────

// ── Enums ────────────────────────────────────────────────────────────────────
enum RoleType { GUEST, USER, ADMIN }

enum SourceType { DIRECT_TEXT, FILE_UPLOAD }

enum ProgrammingLanguage { PYTHON, JAVA, JAVASCRIPT, CPP, TYPESCRIPT, RUST }

extension RoleTypeX on RoleType {
  String get value => name;
  static RoleType fromString(String s) =>
      RoleType.values.firstWhere((e) => e.name == s, orElse: () => RoleType.USER);
}

extension SourceTypeX on SourceType {
  String get value => name;
  static SourceType fromString(String s) =>
      SourceType.values.firstWhere((e) => e.name == s,
          orElse: () => SourceType.DIRECT_TEXT);
}

extension ProgrammingLanguageX on ProgrammingLanguage {
  String get value => name;
  static ProgrammingLanguage fromString(String s) =>
      ProgrammingLanguage.values.firstWhere((e) => e.name == s.toUpperCase(),
          orElse: () => ProgrammingLanguage.PYTHON);

  /// Map sang label hiển thị UI
  String get displayName => switch (this) {
        ProgrammingLanguage.PYTHON => 'Python',
        ProgrammingLanguage.JAVASCRIPT => 'JavaScript',
        ProgrammingLanguage.TYPESCRIPT => 'TypeScript',
        ProgrammingLanguage.JAVA => 'Java',
        ProgrammingLanguage.CPP => 'C++',
        ProgrammingLanguage.RUST => 'Rust',
      };

  /// Map từ key thường (ví dụ 'python') của UI sang enum
  static ProgrammingLanguage fromUiKey(String key) {
    switch (key.toLowerCase()) {
      case 'python':
        return ProgrammingLanguage.PYTHON;
      case 'javascript':
      case 'js':
        return ProgrammingLanguage.JAVASCRIPT;
      case 'typescript':
      case 'ts':
        return ProgrammingLanguage.TYPESCRIPT;
      case 'java':
        return ProgrammingLanguage.JAVA;
      case 'cpp':
      case 'c++':
        return ProgrammingLanguage.CPP;
      case 'rust':
        return ProgrammingLanguage.RUST;
      default:
        return ProgrammingLanguage.PYTHON;
    }
  }
}

// ── User ─────────────────────────────────────────────────────────────────────
class UserModel {
  final int userId;
  final String email;
  final String? fullName;
  final RoleType role;
  final DateTime createdAt;

  const UserModel({
    required this.userId,
    required this.email,
    this.fullName,
    required this.role,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        userId: json['user_id'] as int,
        email: json['email'] as String,
        fullName: json['full_name'] as String?,
        role: RoleTypeX.fromString(json['role'] as String? ?? 'USER'),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'email': email,
        'full_name': fullName,
        'role': role.name,
        'created_at': createdAt.toIso8601String(),
      };

  bool get isAdmin => role == RoleType.ADMIN;
}

// ── Document ─────────────────────────────────────────────────────────────────
class DocumentModel {
  final int? docId;
  final int? userId;
  final String title;
  final SourceType sourceType;
  final ProgrammingLanguage language;
  final String rawCodeContext;
  final String contentMd;
  final int? timeTakenMs;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DocumentModel({
    this.docId,
    this.userId,
    required this.title,
    required this.sourceType,
    required this.language,
    required this.rawCodeContext,
    required this.contentMd,
    this.timeTakenMs,
    this.createdAt,
    this.updatedAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) => DocumentModel(
        docId: json['doc_id'] as int?,
        userId: json['user_id'] as int?,
        title: json['title'] as String? ?? '',
        sourceType: SourceTypeX.fromString(json['source_type'] as String? ?? 'DIRECT_TEXT'),
        language: ProgrammingLanguageX.fromString(json['language'] as String? ?? 'PYTHON'),
        rawCodeContext: json['raw_code_context'] as String? ?? '',
        contentMd: json['content_md'] as String? ?? '',
        timeTakenMs: json['time_taken_ms'] as int?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );
}

// ── Audit Log ────────────────────────────────────────────────────────────────
class AuditLogModel {
  final int logId;
  final int? userId;
  final String action;
  final String? details;
  final DateTime createdAt;

  const AuditLogModel({
    required this.logId,
    this.userId,
    required this.action,
    this.details,
    required this.createdAt,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) => AuditLogModel(
        logId: json['log_id'] as int,
        userId: json['user_id'] as int?,
        action: json['action'] as String,
        details: json['details'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

// ── Admin Stats ──────────────────────────────────────────────────────────────
class AdminStatsModel {
  final int totalUsers;
  final int totalDocs;
  final int totalAdmins;
  final List<LangStat> byLanguage;

  const AdminStatsModel({
    required this.totalUsers,
    required this.totalDocs,
    required this.totalAdmins,
    required this.byLanguage,
  });

  factory AdminStatsModel.fromJson(Map<String, dynamic> json) => AdminStatsModel(
        totalUsers: json['total_users'] as int? ?? 0,
        totalDocs: json['total_docs'] as int? ?? 0,
        totalAdmins: json['total_admins'] as int? ?? 0,
        byLanguage: (json['by_language'] as List? ?? [])
            .map((e) => LangStat.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class LangStat {
  final String language;
  final int count;
  const LangStat({required this.language, required this.count});

  factory LangStat.fromJson(Map<String, dynamic> json) => LangStat(
        language: json['language'] as String,
        count: json['count'] as int,
      );
}
