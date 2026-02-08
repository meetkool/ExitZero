import 'dart:ui';
import 'package:flutter/material.dart';

/// A fully customizable card template for the bento-grid dashboard.
///
/// Usage:
/// ```dart
/// BentoCard(
///   height: 180,
///   gradient: LinearGradient(...),
///   child: Text('Hello'),
/// )
/// ```
///
/// Supports:
/// - Solid color or gradient backgrounds
/// - Glassmorphism (frosted glass) via [glassmorphism]
/// - Custom border, shadow, padding, radius
/// - Optional fixed [height] or content-driven sizing
/// - Any child widget (text, charts, animations, images…)
class BentoCard extends StatelessWidget {
  /// Fixed height of the card. When null the card sizes itself to content.
  final double? height;

  /// The content inside the card — can be literally anything.
  final Widget child;

  /// Padding around [child]. Defaults to 20 on all sides.
  final EdgeInsets padding;

  /// Corner radius. Defaults to 24.
  final double borderRadius;

  /// Optional gradient background (takes priority over [backgroundColor]).
  final Gradient? gradient;

  /// Solid background color. Ignored if [gradient] is set.
  final Color? backgroundColor;

  /// Optional border (e.g. for the accountability "warning" card).
  final BoxBorder? border;

  /// Optional box shadows.
  final List<BoxShadow>? boxShadow;

  /// Enable glassmorphism (frosted-glass) effect.
  /// Sets a translucent white background + backdrop blur.
  final bool glassmorphism;

  /// Optional widget layered behind the child (e.g. a big faded icon).
  final Widget? backgroundDecoration;

  /// Called when the card is tapped. Null = not tappable.
  final VoidCallback? onTap;

  const BentoCard({
    super.key,
    this.height,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.gradient,
    this.backgroundColor,
    this.border,
    this.boxShadow,
    this.glassmorphism = false,
    this.backgroundDecoration,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = glassmorphism
        ? Colors.white.withValues(alpha: 0.08)
        : (backgroundColor ?? Colors.transparent);

    final effectiveBorder = glassmorphism
        ? Border.all(color: Colors.white.withValues(alpha: 0.08))
        : border;

    Widget card = Container(
      height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? effectiveBg : null,
        borderRadius: BorderRadius.circular(borderRadius),
        border: effectiveBorder,
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: glassmorphism
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: _buildContent(),
              )
            : _buildContent(),
      ),
    );

    if (onTap != null) {
      card = GestureDetector(onTap: onTap, child: card);
    }

    return card;
  }

  Widget _buildContent() {
    return Stack(
      children: [
        if (backgroundDecoration != null) backgroundDecoration!,
        Padding(
          padding: padding,
          child: child,
        ),
      ],
    );
  }
}
