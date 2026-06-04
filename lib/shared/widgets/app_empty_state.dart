import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.eyebrow,
    this.supportingNote,
    this.highlights = const <String>[],
    this.actionIcon,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? eyebrow;
  final String? supportingNote;
  final List<String> highlights;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.surfacePrimary,
            palette.surfaceSecondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.borderSoft),
        boxShadow: AppShadows.softCard,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (eyebrow != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                eyebrow!,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          _EmptyStateIllustration(icon: icon),
          const SizedBox(height: AppSpacing.xl),
          Text(
            title,
            style: AppTypography.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: palette.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                for (final highlight in highlights)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfacePrimary.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: palette.borderSoft),
                    ),
                    child: Text(
                      highlight,
                      style: AppTypography.bodySmall.copyWith(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (supportingNote != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: palette.surfacePrimary.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppRadius.formCard),
                border: Border.all(color: palette.borderSoft),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      supportingNote!,
                      style: AppTypography.bodySmall.copyWith(
                        color: palette.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.add_rounded, color: Colors.white),
                label: Text(
                  actionLabel!,
                  style: AppTypography.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: AppColors.brandPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyStateIllustration extends StatefulWidget {
  const _EmptyStateIllustration({required this.icon});

  final IconData icon;

  @override
  State<_EmptyStateIllustration> createState() => _EmptyStateIllustrationState();
}

class _EmptyStateIllustrationState extends State<_EmptyStateIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          height: 120,
          width: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
              ),
              Transform.translate(
                offset: Offset(0, -_animation.value),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.translate(
                      offset: const Offset(-20, 10),
                      child: Transform.rotate(
                        angle: -0.14,
                        child: _PaperCard(
                          color: palette.surfaceSecondary,
                          borderColor: palette.borderSoft,
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(20, 8),
                      child: Transform.rotate(
                        angle: 0.12,
                        child: _PaperCard(
                          color: palette.surfaceSecondary,
                          borderColor: palette.borderSoft,
                        ),
                      ),
                    ),
                    Container(
                      width: 72,
                      height: 92,
                      decoration: BoxDecoration(
                        color: palette.surfacePrimary,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: palette.borderPrimary),
                        boxShadow: AppShadows.softCard,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        widget.icon,
                        size: 30,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                right: 32,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: AppColors.brandPrimary.withValues(alpha: 0.28),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 32,
                child: Icon(
                  Icons.circle,
                  size: 6,
                  color: AppColors.brandLavender.withValues(alpha: 0.24),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PaperCard extends StatelessWidget {
  const _PaperCard({
    required this.color,
    required this.borderColor,
  });

  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 82,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
    );
  }
}
