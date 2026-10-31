import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

/// GlassBackground provides an authentic ambient gradient backdrop
/// that shines through frosted liquid glass containers and app bars.
class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = settings.primaryColor;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base color layer
        ColoredBox(
          color: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
        ),

        // Ambient glowing orb (Top Right)
        Positioned(
          top: -120,
          right: -80,
          child: Container(
            width: 450,
            height: 450,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primaryColor.withValues(alpha: isDark ? 0.24 : 0.12),
                  primaryColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),

        // Ambient glowing orb (Bottom Left)
        Positioned(
          bottom: -150,
          left: -100,
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (isDark ? const Color(0xFF6366F1) : const Color(0xFF0284C7))
                      .withValues(alpha: isDark ? 0.18 : 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Subtle center accent mesh
        Positioned(
          top: MediaQuery.of(context).size.height * 0.35,
          left: MediaQuery.of(context).size.width * 0.25,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primaryColor.withValues(alpha: isDark ? 0.08 : 0.04),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Content
        child,
      ],
    );
  }
}

/// A drop-in replacement for Scaffold with built-in GlassBackground
class GlassScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? drawer;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool extendBodyBehindAppBar;
  final bool resizeToAvoidBottomInset;

  const GlassScaffold({
    super.key,
    this.appBar,
    this.body,
    this.drawer,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      drawer: drawer,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: GlassBackground(
        child: SafeArea(
          top: !extendBodyBehindAppBar,
          child: body ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
