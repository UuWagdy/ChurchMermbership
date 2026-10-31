import 'package:flutter/material.dart';
import 'package:liquidify/liquidify.dart';
import '../theme/app_theme.dart';

/// GlassCard renders an authentic Apple-style liquid glass surface using Liquidify.
/// Ensures maximum contrast for text and child widgets in both light and dark modes.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final Color? customTint;
  final BoxBorder? border;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 18.0,
    this.onTap,
    this.width,
    this.height,
    this.customTint,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.primaryColor;

    final resolvedRadius = BorderRadius.circular(borderRadius);

    final glassOptions = AppTheme.getLiquidGlassOptions(
      isDark: isDark,
      primaryColor: primary,
    ).copyWith(
      borderRadius: resolvedRadius,
      tint: customTint,
      border: border,
    );

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: LiquidGlassContainer(
        options: glassOptions,
        borderRadius: resolvedRadius,
        padding: padding,
        onTap: onTap,
        child: child,
      ),
    );
  }
}
