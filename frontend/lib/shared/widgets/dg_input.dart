import 'package:flutter/material.dart';
import '../../core/tokens/app_colors.dart';
import '../../core/tokens/app_typography.dart';

/// DocGen VN — text input field
///
/// DgInput(label: 'Email', hint: 'ban@email.com', controller: _ctrl)
/// DgInput.password(label: 'Mật khẩu', controller: _ctrl)
class DgInput extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool readOnly;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;

  const DgInput({
    super.key,
    this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.controller,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.prefixIcon,
    this.suffix,
    this.onChanged,
    this.onTap,
    this.validator,
    this.textInputAction,
    this.onEditingComplete,
  });

  factory DgInput.password({
    String? label,
    String? hint,
    String? errorText,
    TextEditingController? controller,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
  }) =>
      DgInput(
        label: label ?? 'Mật khẩu',
        hint: hint ?? '••••••••',
        errorText: errorText,
        controller: controller,
        focusNode: focusNode,
        obscureText: true,
        prefixIcon: Icons.lock_outline,
        onChanged: onChanged,
        validator: validator,
        textInputAction: textInputAction,
      );

  factory DgInput.search({
    String? hint,
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
  }) =>
      DgInput(
        hint: hint ?? 'Tìm kiếm...',
        controller: controller,
        prefixIcon: Icons.search,
        onChanged: onChanged,
        keyboardType: TextInputType.text,
      );

  @override
  State<DgInput> createState() => _DgInputState();
}

class _DgInputState extends State<DgInput> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final fg        = isDark ? AppColors.fgDark         : AppColors.fgLight;
    final muted     = isDark ? AppColors.fgSubtleDark   : AppColors.fgSubtleLight;
    final bg        = isDark ? AppColors.cardDark        : AppColors.cardLight;
    final border    = isDark ? AppColors.borderDark      : AppColors.borderLight;
    final errorColor = AppColors.error;

    final hasError  = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.bodySmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
        ],

        // Field
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscureText && _obscure,
          readOnly: widget.readOnly,
          autofocus: widget.autofocus,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          minLines: widget.minLines,
          onChanged: widget.onChanged,
          onTap: widget.onTap,
          validator: widget.validator,
          textInputAction: widget.textInputAction,
          onEditingComplete: widget.onEditingComplete,
          style: AppTypography.body.copyWith(color: fg),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTypography.body.copyWith(color: muted),
            filled: true,
            fillColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, size: 16, color: muted)
                : null,
            prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            suffixIcon: widget.obscureText
                ? GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 16,
                      color: muted,
                    ),
                  )
                : widget.suffix,
            suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: hasError ? errorColor : border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: hasError ? errorColor : border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: hasError ? errorColor : AppColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            // Suppress the built-in error text — we render our own below
            errorText: null,
            errorStyle: const TextStyle(height: 0, fontSize: 0),
          ),
        ),

        // Helper / Error text
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.error_outline, size: 13, color: AppColors.error),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.errorText!,
                  style: AppTypography.caption.copyWith(color: errorColor),
                ),
              ),
            ],
          ),
        ] else if (widget.helperText != null) ...[
          const SizedBox(height: 5),
          Text(
            widget.helperText!,
            style: AppTypography.caption.copyWith(color: muted),
          ),
        ],
      ],
    );
  }
}
