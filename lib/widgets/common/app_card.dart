import 'package:flutter/material.dart';

import '../../core/themes/app_decorations.dart';
import '../../core/themes/app_spacing.dart';

enum AppCardVariant { standard, elevated, premium, glass }

class AppCard extends StatelessWidget {
  final Widget child;
  final AppCardVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final BoxDecoration? decoration;
  final Clip clipBehavior;

  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.standard,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
    this.width,
    this.height,
    this.decoration,
    this.clipBehavior = Clip.antiAlias,
  });

  BoxDecoration get _decoration {
    final defaultDecoration = switch (variant) {
      AppCardVariant.standard => AppDecorations.card,
      AppCardVariant.elevated => AppDecorations.elevatedCard,
      AppCardVariant.premium => AppDecorations.premiumCard,
      AppCardVariant.glass => AppDecorations.glassCard,
    };

    if (decoration != null) {
      return decoration!;
    }

    if (borderRadius != null) {
      return defaultDecoration.copyWith(borderRadius: borderRadius);
    }

    return defaultDecoration;
  }

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: _decoration,
      clipBehavior: clipBehavior,
      child: Padding(padding: padding ?? AppSpacing.cardPadding, child: child),
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        borderRadius:
            borderRadius ?? BorderRadius.circular(AppSpacing.radiusLarge),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius:
              borderRadius ?? BorderRadius.circular(AppSpacing.radiusLarge),
          splashColor: Colors.white.withValues(alpha: 0.05),
          highlightColor: Colors.white.withValues(alpha: 0.025),
          child: card,
        ),
      );
    }

    return card;
  }
}
