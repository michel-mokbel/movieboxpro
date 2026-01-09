import 'package:flutter/material.dart';
import 'package:moviemagicbox/utils/bento_theme.dart';

class BentoCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Gradient? gradient;
  final Color? color;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;

  const BentoCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(
      Radius.circular(BentoTheme.radiusMedium),
    ),
    this.gradient,
    this.color,
    this.border,
    this.boxShadow,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color ?? BentoTheme.surface,
      gradient: gradient,
      borderRadius: borderRadius,
      border: border ?? Border.all(color: BentoTheme.outline),
      boxShadow: boxShadow ??
          [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
    );

    final content = Ink(
      width: width,
      height: height,
      decoration: decoration,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    return Material(
      color: Colors.transparent,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              child: content,
            ),
    );
  }
}
