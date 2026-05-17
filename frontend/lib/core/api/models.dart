// lib/core/api/models.dart
import 'package:flutter/material.dart';
import 'api_config.dart';

// ════════════════════════════════════════════════════════════════════════════
// ENUMS
// ════════════════════════════════════════════════════════════════════════════

enum RoleType { GUEST, USER, ADMIN }

enum SourceType {
  DIRECT_TEXT,
  FILE_UPLOAD;

  String get value => name;
}

enum AIModelType { GROQ_LLAMA3, KAGGLE_FINETUNED }

enum ProgrammingLanguage {
  PYTHON,
  JAVA,
  JAVASCRIPT,
  CPP,
  TYPESCRIPT,
  RUST;

  String get displayName => switch (this) {
    PYTHON => 'Python',
    JAVA => 'Java',
    JAVASCRIPT => 'JavaScript',
    CPP => 'C++',
    TYPESCRIPT => 'TypeScript',
    RUST => 'Rust',
  };

  String get value => name;
  String get uiKey => name.toLowerCase();

  static ProgrammingLanguage fromUiKey(String key) {
    return ProgrammingLanguage.values.firstWhere(
          (e) => e.uiKey == key.toLowerCase(),
      orElse: () => ProgrammingLanguage.PYTHON,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MODELS
// ════════════════════════════════════════════════════════════════════════════

class User {
  final int userId;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final RoleType role;
  final bool isActive;
  final bool isLocked;
  final DateTime createdAt;

  bool get isAdmin => role == RoleType.ADMIN;

  User({
    required this.userId,
    required this.email,
    this.fullName,
    this.avatarUrl,
    required this.role,
    required this.isActive,
    required this.isLocked,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      email: json['email'] ?? '',
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'] != null ? ApiConfig.assetUrl(json['avatar_url'] as String) : null,
      role: RoleType.values.firstWhere(
            (e) => e.name == (json['role'] ?? 'USER'),
        orElse: () => RoleType.USER,
      ),
      isActive: json['is_active'] ?? true,
      isLocked: json['is_locked'] ?? false,
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Strip baseUrl trước khi lưu cache — tránh nối URL 2 lần khi restore
  String? get _rawAvatarPath {
    if (avatarUrl == null) return null;
    final base = ApiConfig.baseUrl;
    if (avatarUrl!.startsWith(base)) return avatarUrl!.substring(base.length);
    return avatarUrl;
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'email': email,
    'full_name': fullName,
    'avatar_url': _rawAvatarPath,
    'role': role.name,
    'is_active': isActive,
    'is_locked': isLocked,
    'created_at': createdAt.toIso8601String(),
  };

  User copyWith({
    String? fullName,
    String? avatarUrl,
    String? email,
    bool? isLocked,
    bool? isActive,
  }) =>
      User(
        userId: userId,
        email: email ?? this.email,
        fullName: fullName ?? this.fullName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        role: role,
        isActive: isActive ?? this.isActive,
        isLocked: isLocked ?? this.isLocked,
        createdAt: createdAt,
      );
}

class Document {
  final int? docId;
  final int userId;
  final String title;
  final SourceType sourceType;
  final ProgrammingLanguage language;
  final String rawCodeContext;
  final String contentMd;
  final int? timeTakenMs;
  final DateTime createdAt;
  final DateTime updatedAt;

  Document({
    this.docId,
    required this.userId,
    required this.title,
    required this.sourceType,
    required this.language,
    required this.rawCodeContext,
    required this.contentMd,
    this.timeTakenMs,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      docId: json['doc_id'],
      userId: json['user_id'],
      title: json['title'] ?? 'Không tiêu đề',
      sourceType: SourceType.values.firstWhere(
            (e) => e.name == json['source_type'],
        orElse: () => SourceType.DIRECT_TEXT,
      ),
      language: ProgrammingLanguage.values.firstWhere(
            (e) => e.name == json['language'],
        orElse: () => ProgrammingLanguage.PYTHON,
      ),
      rawCodeContext: json['raw_code_context'] ?? '',
      contentMd: json['content_md'] ?? '',
      timeTakenMs: json['time_taken_ms'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] ?? json['created_at']).toLocal(),
    );
  }

  Document copyWith({String? contentMd, String? title}) => Document(
    docId: docId,
    userId: userId,
    title: title ?? this.title,
    sourceType: sourceType,
    language: language,
    rawCodeContext: rawCodeContext,
    contentMd: contentMd ?? this.contentMd,
    timeTakenMs: timeTakenMs,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}

class AuditLog {
  final int logId;
  final int? userId;
  final String action;
  final String? details;
  final DateTime createdAt;

  AuditLog({
    required this.logId,
    this.userId,
    required this.action,
    this.details,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      logId: json['log_id'],
      userId: json['user_id'],
      action: json['action'] ?? '',
      details: json['details'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }
}

class AIModelConfig {
  final int id;
  final AIModelType modelType;
  final bool isActive;
  final String? description;

  AIModelConfig({
    required this.id,
    required this.modelType,
    required this.isActive,
    this.description,
  });

  factory AIModelConfig.fromJson(Map<String, dynamic> json) {
    return AIModelConfig(
      id: json['id'],
      modelType: AIModelType.values.firstWhere(
            (e) => e.name == json['model_type'],
        orElse: () => AIModelType.GROQ_LLAMA3,
      ),
      isActive: json['is_active'] ?? true,
      description: json['description'],
    );
  }

  String get displayName => switch (modelType) {
    AIModelType.GROQ_LLAMA3 => 'Llama 3.1 8B (Groq)',
    AIModelType.KAGGLE_FINETUNED => 'Llama 3.1B Finetune (Kaggle)',
  };
}

class Feedback {
  final int? id;
  final int userId;
  final int rating;
  final String? content;
  final DateTime? createdAt;

  Feedback({
    this.id,
    required this.userId,
    required this.rating,
    this.content,
    this.createdAt,
  });

  factory Feedback.fromJson(Map<String, dynamic> json) {
    return Feedback(
      id: json['id'],
      userId: json['user_id'],
      rating: json['rating'] ?? 5,
      content: json['content'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'rating': rating,
    'content': content,
  };
}

// ════════════════════════════════════════════════════════════════════════════
// ADMIN MODELS
// ════════════════════════════════════════════════════════════════════════════

typedef AuditLogModel = AuditLog;

class LangStat {
  final String language;
  final int count;

  const LangStat({required this.language, required this.count});

  factory LangStat.fromJson(Map<String, dynamic> json) => LangStat(
    language: json['language'] as String? ?? '',
    count: json['count'] as int? ?? 0,
  );
}

class DateStat {
  final String date;
  final int count;
  const DateStat({required this.date, required this.count});
  factory DateStat.fromJson(Map<String, dynamic> json) => DateStat(
    date: json['date'] as String? ?? '',
    count: json['count'] as int? ?? 0,
  );
}

class AdminStatsModel {
  final int totalUsers;
  final int totalDocs;
  final int totalAdmins;
  final int pendingRequests;
  final int activeUsers;
  final int lockedUsers;
  final int docsToday;
  final int avgTimeMs;
  final List<LangStat> byLanguage;
  final List<LangStat> byModel;
  final List<DateStat> docsOverTime;

  const AdminStatsModel({
    required this.totalUsers,
    required this.totalDocs,
    this.totalAdmins = 0,
    this.pendingRequests = 0,
    this.activeUsers = 0,
    this.lockedUsers = 0,
    this.docsToday = 0,
    this.avgTimeMs = 0,
    required this.byLanguage,
    this.byModel = const [],
    this.docsOverTime = const [],
  });

  factory AdminStatsModel.fromJson(Map<String, dynamic> json) =>
      AdminStatsModel(
        totalUsers: json['total_users'] as int? ?? 0,
        totalDocs: json['total_documents'] as int? ?? json['total_docs'] as int? ?? 0,
        totalAdmins: 0,
        pendingRequests: json['pending_requests'] as int? ?? 0,
        activeUsers: json['active_users'] as int? ?? 0,
        lockedUsers: json['locked_users'] as int? ?? 0,
        docsToday: json['docs_today'] as int? ?? 0,
        avgTimeMs: json['avg_time_ms'] as int? ?? 0,
        byLanguage: (json['by_language'] as List<dynamic>? ?? [])
            .map((e) => LangStat.fromJson(e as Map<String, dynamic>))
            .toList(),
        byModel: (json['by_model'] as List<dynamic>? ?? [])
            .map((e) => LangStat.fromJson({
          'language': (e as Map<String, dynamic>)['model'] ?? '',
          'count': e['count'] ?? 0,
        }))
            .toList(),
        docsOverTime: (json['docs_over_time'] as List<dynamic>? ?? [])
            .map((e) => DateStat.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Thông tin chi tiết user cho Admin (gồm lịch sử sử dụng)
class UserDetailModel {
  final User user;
  final int totalDocs;
  final List<Document> recentDocs;
  final DateTime? lastActiveAt;

  const UserDetailModel({
    required this.user,
    required this.totalDocs,
    required this.recentDocs,
    this.lastActiveAt,
  });

  factory UserDetailModel.fromJson(Map<String, dynamic> json) =>
      UserDetailModel(
        user: User.fromJson(json['user'] as Map<String, dynamic>),
        // backend trả về total_documents
        totalDocs: json['total_documents'] as int? ?? json['total_docs'] as int? ?? 0,
        // backend trả về recent_documents
        recentDocs: (json['recent_documents'] as List<dynamic>? ??
            json['recent_docs'] as List<dynamic>? ?? [])
            .map((e) => Document.fromJson(e as Map<String, dynamic>))
            .toList(),
        lastActiveAt: json['last_active_at'] != null
            ? DateTime.tryParse(json['last_active_at'] as String)?.toLocal()
            : null,
      );
}

// ════════════════════════════════════════════════════════════════════════════
// HELPER EXTENSIONS
// ════════════════════════════════════════════════════════════════════════════

extension ProgrammingLanguageX on ProgrammingLanguage {
  IconData get icon => switch (this) {
    ProgrammingLanguage.PYTHON => Icons.terminal,
    ProgrammingLanguage.JAVA => Icons.coffee,
    ProgrammingLanguage.JAVASCRIPT => Icons.javascript,
    ProgrammingLanguage.CPP => Icons.settings,
    ProgrammingLanguage.TYPESCRIPT => Icons.code,
    ProgrammingLanguage.RUST => Icons.build,
  };
}

// ════════════════════════════════════════════════════════════════════════════
// CONTACT MESSAGE — Tin nhắn từ form Liên hệ trên landing page
// ════════════════════════════════════════════════════════════════════════════
class ContactMessage {
  final int id;
  final String? name;
  final String email;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  const ContactMessage({
    required this.id,
    this.name,
    required this.email,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory ContactMessage.fromJson(Map<String, dynamic> json) => ContactMessage(
    id: json['id'] as int,
    name: json['name'] as String?,
    email: json['email'] as String,
    content: json['content'] as String,
    isRead: json['is_read'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );
}