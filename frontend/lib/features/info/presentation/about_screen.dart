// lib/features/info/presentation/about_screen.dart
// Trang Giới thiệu - yêu cầu I.13

import 'package:flutter/material.dart';

import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '_info_shell.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InfoShell(
      title: 'Giới thiệu dự án',
      subtitle:
      'DocGen VN - Hệ thống AI sinh tài liệu mã nguồn bằng Tiếng Việt sử dụng GraphRAG',
      icon: Icons.school_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoSection(
            title: 'Về dự án',
            children: const [
              InfoParagraph(
                'DocGen VN là sản phẩm của nhóm sinh viên trong khuôn khổ học phần Khai phá dữ liệu '
                    'tại Đại học Quốc gia Hà Nội. Mục tiêu của dự án là xây dựng một hệ thống AI có khả năng '
                    'phân tích mã nguồn và tự động sinh tài liệu kỹ thuật bằng Tiếng Việt, hỗ trợ '
                    'cộng đồng lập trình viên Việt Nam.',
              ),
              InfoParagraph(
                'Hệ thống áp dụng kiến trúc GraphRAG (Graph-based Retrieval-Augmented Generation), '
                    'kết hợp phân tích cây cú pháp trừu tượng (AST) với mô hình ngôn ngữ lớn (Llama 3.1) '
                    'để hiểu sâu cấu trúc và ngữ nghĩa của mã nguồn trước khi sinh tài liệu.',
              ),
            ],
          ),
          InfoSection(
            title: 'Giảng viên hướng dẫn',
            children: [
              _TeacherCard(),
            ],
          ),
          InfoSection(
            title: 'Môn học',
            children: const [
              InfoParagraph(
                'Khai phá dữ liệu (Data Mining) - Viện Công nghệ Thông tin, '
                    'Đại học Quốc gia Hà Nội. Học phần cung cấp kiến thức nền tảng và nâng cao về '
                    'các kỹ thuật trích xuất tri thức từ dữ liệu lớn: phân lớp, phân cụm, hồi quy, '
                    'khai phá luật kết hợp, và các kiến trúc Deep Learning hiện đại.',
              ),
            ],
          ),
          InfoSection(
            title: 'Công nghệ sử dụng',
            children: [
              _TechGroup(
                title: 'Frontend',
                items: const [
                  'Flutter Web - Framework UI đa nền tảng của Google',
                  'Riverpod - Quản lý state',
                  'GoRouter - Định tuyến',
                  'flutter_markdown - Hiển thị Markdown',
                  'fl_chart - Biểu đồ Admin Dashboard',
                ],
              ),
              _TechGroup(
                title: 'Backend',
                items: const [
                  'FastAPI (Python 3.11) - REST API hiệu năng cao',
                  'SQLAlchemy 2.0 - ORM',
                  'PostgreSQL + pgvector - Cơ sở dữ liệu',
                  'Tree-sitter - Phân tích AST đa ngôn ngữ',
                  'WeasyPrint + python-docx - Xuất PDF / DOCX',
                  'Bcrypt + JWT-like sessions - Xác thực',
                ],
              ),
              _TechGroup(
                title: 'AI / ML',
                items: const [
                  'Llama 3.1 8B Instant - Groq Cloud',
                  'Llama 3.1 finetuned on Kaggle',
                  'sentence-transformers - Embedding',
                  'GraphRAG - Truy xuất đồ thị tri thức',
                  'PyTorch + Transformers',
                ],
              ),
              _TechGroup(
                title: 'Hạ tầng',
                items: const [
                  'AWS EC2 (Ubuntu) - Máy chủ',
                  'Docker + Docker Compose - Đóng gói',
                  'Nginx - Web server / Reverse proxy',
                  'Cloudflare - CDN + bảo mật',
                  'GitHub - Quản lý mã nguồn',
                ],
              ),
            ],
          ),
          InfoSection(
            title: 'Ngôn ngữ lập trình được hỗ trợ',
            children: const [
              InfoBullet('Python (.py)'),
              InfoBullet('Java (.java)'),
              InfoBullet('JavaScript (.js, .jsx)'),
              InfoBullet('TypeScript (.ts, .tsx)'),
              InfoBullet('C++ (.cpp, .cc, .h, .hpp)'),
              InfoBullet('Rust (.rs)'),
            ],
          ),
          InfoSection(
            title: 'Tính năng nổi bật',
            children: const [
              InfoBullet(
                  'Phân tích AST kết hợp đồ thị tri thức để hiểu chính xác cấu trúc code.'),
              InfoBullet(
                  'Sinh tài liệu Tiếng Việt với thuật ngữ kỹ thuật chuẩn xác.'),
              InfoBullet(
                  'Cảnh báo lỗi cú pháp nhưng cho phép người dùng tự quyết định.'),
              InfoBullet(
                  'Xuất tài liệu sang Markdown, PDF, Word - tích hợp dễ dàng vào quy trình làm việc.'),
              InfoBullet(
                  'Lưu trữ phiên bản - chỉnh sửa và so sánh lịch sử tài liệu.'),
              InfoBullet(
                  'Đăng nhập đa nền tảng - Web, Android, iOS.'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeacherCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: card,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Center(
              child: Text('LHS',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: AppSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PGS.TS Lê Hoàng Sơn',
                    style:
                    AppTypography.h4.copyWith(color: fg, fontSize: 18)),
                const SizedBox(height: 4),
                Text(
                  'Phó Viện trưởng Viện Công nghệ Thông tin',
                  style: AppTypography.bodyMedium.copyWith(color: muted),
                ),
                const SizedBox(height: 2),
                Text(
                  'Đại học Quốc gia Hà Nội',
                  style: AppTypography.bodySmall.copyWith(color: muted),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Giảng viên hướng dẫn',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.primary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TechGroup extends StatelessWidget {
  final String title;
  final List<String> items;
  const _TechGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTypography.h4
                  .copyWith(color: fg, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...items.map((i) => InfoBullet(i)),
        ],
      ),
    );
  }
}