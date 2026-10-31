import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../dialogs/theme_color_dialog.dart';

/// ThemeToggleButton is the top app bar action that toggles between
/// Dark Mode and Light Mode on tap, and opens the Theme & Hex Color
/// Customizer dialog on long press.
class ThemeToggleButton extends StatelessWidget {
  final bool compact;
  final bool darkBackground;

  const ThemeToggleButton({
    super.key,
    this.compact = true,
    this.darkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = settings.primaryColor;

    final iconColor = darkBackground
        ? Colors.white
        : (isDark ? const Color(0xFFFBBF24) : primaryColor);

    final tooltip = isDark
        ? 'الوضع الليلي مفعّل (انقر للنهاري، اضغط مطولاً لتخصيص الألوان والـ Hex)'
        : 'الوضع النهاري مفعّل (انقر لليلي، اضغط مطولاً لتخصيص الألوان والـ Hex)';

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            settings.toggleThemeMode();
          },
          onLongPress: () {
            ThemeColorDialog.show(context);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : (darkBackground
                      ? Colors.white.withValues(alpha: 0.15)
                      : primaryColor.withValues(alpha: 0.08)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : (darkBackground
                        ? Colors.white.withValues(alpha: 0.25)
                        : primaryColor.withValues(alpha: 0.20)),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: anim,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    key: ValueKey<bool>(isDark),
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 6),
                // Tiny accent color indicator
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
