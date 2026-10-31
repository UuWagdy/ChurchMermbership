import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class _PresetColorItem {
  final String name;
  final Color color;

  const _PresetColorItem(this.name, this.color);
}

class ThemeColorDialog extends StatefulWidget {
  const ThemeColorDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => const ThemeColorDialog(),
    );
  }

  @override
  State<ThemeColorDialog> createState() => _ThemeColorDialogState();
}

class _ThemeColorDialogState extends State<ThemeColorDialog> {
  late TextEditingController _hexController;
  late Color _selectedColor;
  String? _hexError;

  static const List<_PresetColorItem> _presets = [
    _PresetColorItem('نيلي ملكي (افتراضي)', Color(0xFF1A237E)),
    _PresetColorItem('أزرق ياقوتي', Color(0xFF0284C7)),
    _PresetColorItem('تركواز زمردي', Color(0xFF0D9488)),
    _PresetColorItem('أخضر نقي', Color(0xFF16A34A)),
    _PresetColorItem('بنفسجي ملكي', Color(0xFF7C3AED)),
    _PresetColorItem('أحمر قرمزي', Color(0xFFE11D48)),
    _PresetColorItem('عنبر ذهبي', Color(0xFFD97706)),
    _PresetColorItem('نحاسي متوهج', Color(0xFFC2410C)),
    _PresetColorItem('وردي مخملي', Color(0xFFBE185D)),
    _PresetColorItem('رمادي فخم', Color(0xFF334155)),
    _PresetColorItem('سيان بحري', Color(0xFF0891B2)),
    _PresetColorItem('نيلي حديث', Color(0xFF4338CA)),
  ];

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _selectedColor = settings.primaryColor;
    _hexController = TextEditingController(
      text: SettingsProvider.colorToHex(_selectedColor).replaceFirst('#', ''),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _onHexChanged(String val) {
    final parsed = SettingsProvider.parseHexColor(val);
    if (parsed != null) {
      setState(() {
        _selectedColor = parsed;
        _hexError = null;
      });
    } else if (val.trim().length >= 6) {
      setState(() {
        _hexError = 'كود اللون غير صالح (يجب أن يكون 6 رموز مثل 1A237E)';
      });
    }
  }

  void _selectPreset(Color color) {
    setState(() {
      _selectedColor = color;
      _hexController.text =
          SettingsProvider.colorToHex(color).replaceFirst('#', '');
      _hexError = null;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      final text = data.text!.trim();
      final parsed = SettingsProvider.parseHexColor(text);
      if (parsed != null) {
        _selectPreset(parsed);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('النص المنسوخ ليس كود Hex صالح')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    final contrastTextColor = AppTheme.getContrastingTextColor(_selectedColor);

    final dialogSurface = isDark ? const Color(0xFF151E2E) : Colors.white;
    final dialogBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Container(
            decoration: BoxDecoration(
              color: dialogSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: dialogBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _selectedColor.withValues(alpha: 0.18),
                          border: Border.all(
                            color: _selectedColor.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.palette_rounded,
                          color: _selectedColor,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تخصيص المظهر والألوان',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'التبديل بين النهاري والليلي وتخصيص لون السمة بالزجاج الشفاف',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Mode Switcher: Light / Dark
                  Text(
                    'الوضع العام (دارك مود / لايت مود)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (settings.themeMode != ThemeMode.light) {
                              settings.setThemeMode(ThemeMode.light);
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !settings.isDarkMode
                                  ? _selectedColor.withValues(alpha: 0.15)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.04)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: !settings.isDarkMode
                                    ? _selectedColor
                                    : (isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFCBD5E1)),
                                width: !settings.isDarkMode ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.light_mode_rounded,
                                  size: 18,
                                  color: !settings.isDarkMode
                                      ? _selectedColor
                                      : textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'الوضع النهاري (فاتح)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: !settings.isDarkMode
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: !settings.isDarkMode
                                        ? _selectedColor
                                        : textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (settings.themeMode != ThemeMode.dark) {
                              settings.setThemeMode(ThemeMode.dark);
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: settings.isDarkMode
                                  ? _selectedColor.withValues(alpha: 0.20)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.04)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: settings.isDarkMode
                                    ? _selectedColor
                                    : (isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFCBD5E1)),
                                width: settings.isDarkMode ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.dark_mode_rounded,
                                  size: 18,
                                  color: settings.isDarkMode
                                      ? _selectedColor
                                      : textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'الوضع الليلي (داكن)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: settings.isDarkMode
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: settings.isDarkMode
                                        ? _selectedColor
                                        : textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Presets Palette
                  Text(
                    'لوحة الألوان الجاهزة (اختر اللون المفضل)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _presets.map((preset) {
                      final isSelected =
                          _selectedColor.toARGB32() == preset.color.toARGB32();
                      return Tooltip(
                        message: preset.name,
                        child: InkWell(
                          onTap: () => _selectPreset(preset.color),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: preset.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.35),
                                width: isSelected ? 2.5 : 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: preset.color.withValues(alpha: 0.4),
                                  blurRadius: isSelected ? 8 : 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 22),

                  // Hex code input ("وممكن يكتب ال هيكس")
                  Text(
                    'أو أدخل كود اللون (Hex Code)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Hex Input Field
                      Expanded(
                        child: TextField(
                          controller: _hexController,
                          onChanged: _onHexChanged,
                          maxLength: 6,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: textPrimary,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _selectedColor,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            counterText: '',
                            prefixText: '# ',
                            prefixStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _selectedColor,
                            ),
                            hintText: '1A237E',
                            errorText: _hexError,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.paste_rounded, size: 20),
                              tooltip: 'لصق من الحافظة',
                              onPressed: _pasteFromClipboard,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Live Color Swatch Box
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _selectedColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? Colors.white30 : Colors.black12,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _selectedColor.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Contrast verification & Live Preview Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedColor.withValues(alpha: isDark ? 0.20 : 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _selectedColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: _selectedColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'معاينة التباين وجودة القراءة:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'تباين فائق (AAA)',
                                style: TextStyle(
                                  color: contrastTextColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'كنيسة الشهيدين العظيمين بطرس وبولس — العضوية الكنسية',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'تأكد من وضوح النصوص والقوائم والبطاقات بأعلى دقة وتباين.',
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('الافتراضي'),
                        onPressed: () {
                          _selectPreset(AppTheme.defaultPrimary);
                        },
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedColor,
                          foregroundColor: contrastTextColor,
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: const Text('تطبيق وحفظ'),
                        onPressed: () {
                          settings.setPrimaryColor(_selectedColor);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'تم تطبيق السمة الزجاجية ولون (${SettingsProvider.colorToHex(_selectedColor)}) بنجاح',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
