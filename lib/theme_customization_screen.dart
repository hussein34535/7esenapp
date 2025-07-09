import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flex_color_picker/flex_color_picker.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  // Light mode colors
  Color _lightPrimaryColor = const Color(0xFF673AB7);
  Color _lightScaffoldBackgroundColor = const Color(0xFF673AB7);
  Color _lightCardColor = const Color(0xFF673AB7);
  Color _lightAppBarBackgroundColor = const Color(0xFF673AB7);
  Color _lightSecondaryColor = const Color(0xFF00BCD4);

  // Dark mode colors
  Color _darkPrimaryColor = const Color(0xFF673AB7);
  Color _darkScaffoldBackgroundColor = Colors.black;
  Color _darkCardColor = const Color(0xFF1C1C1C);
  Color _darkAppBarBackgroundColor = const Color.fromARGB(255, 0, 0, 0);
  Color _darkSecondaryColor = const Color.fromARGB(255, 184, 28, 176);

  // Getters based on theme mode
  Color getPrimaryColor(bool isDarkMode) =>
      isDarkMode ? _darkPrimaryColor : _lightPrimaryColor;
  Color getScaffoldBackgroundColor(bool isDarkMode) =>
      isDarkMode ? _darkScaffoldBackgroundColor : _lightScaffoldBackgroundColor;
  Color getCardColor(bool isDarkMode) =>
      isDarkMode ? _darkCardColor : _lightCardColor;
  Color getAppBarBackgroundColor(bool isDarkMode) =>
      isDarkMode ? _darkAppBarBackgroundColor : _lightAppBarBackgroundColor;
  Color getSecondaryColor(bool isDarkMode) =>
      isDarkMode ? _darkSecondaryColor : _lightSecondaryColor;

  ThemeProvider() {
    _loadAllColors();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final savedThemeMode = prefs.getString('themeMode');
    if (savedThemeMode != null) {
      _themeMode = savedThemeMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    notifyListeners();
  }

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode newThemeMode) async {
    _themeMode = newThemeMode;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'themeMode', newThemeMode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  void _loadAllColors() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Load light mode colors
    _lightPrimaryColor = Color(
        prefs.getInt('lightPrimaryColor') ?? const Color(0xFF673AB7).value);
    _lightScaffoldBackgroundColor = Color(
        prefs.getInt('lightScaffoldBackgroundColor') ??
            const Color(0xFF673AB7).value);
    _lightCardColor =
        Color(prefs.getInt('lightCardColor') ?? const Color(0xFF673AB7).value);
    _lightAppBarBackgroundColor = Color(
        prefs.getInt('lightAppBarBackgroundColor') ??
            const Color(0xFF673AB7).value);
    _lightSecondaryColor = Color(
        prefs.getInt('lightSecondaryColor') ?? const Color(0xFF00BCD4).value);

    // Load dark mode colors
    _darkPrimaryColor = Color(
        prefs.getInt('darkPrimaryColor') ?? const Color(0xFF673AB7).value);
    _darkScaffoldBackgroundColor = Color(
        prefs.getInt('darkScaffoldBackgroundColor') ?? Colors.black.value);
    _darkCardColor =
        Color(prefs.getInt('darkCardColor') ?? const Color(0xFF1C1C1C).value);
    _darkAppBarBackgroundColor = Color(
        prefs.getInt('darkAppBarBackgroundColor') ??
            const Color.fromARGB(255, 0, 0, 0).value);
    _darkSecondaryColor = Color(prefs.getInt('darkSecondaryColor') ??
        const Color.fromARGB(255, 184, 28, 176).value);

    notifyListeners();
  }

  void setPrimaryColor(Color color, bool isDarkMode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (isDarkMode) {
      _darkPrimaryColor = color;
      await prefs.setInt('darkPrimaryColor', color.value);
    } else {
      _lightPrimaryColor = color;
      await prefs.setInt('lightPrimaryColor', color.value);
    }
    notifyListeners();
  }

  void setScaffoldBackgroundColor(Color color, bool isDarkMode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (isDarkMode) {
      _darkScaffoldBackgroundColor = color;
      await prefs.setInt('darkScaffoldBackgroundColor', color.value);
    } else {
      _lightScaffoldBackgroundColor = color;
      await prefs.setInt('lightScaffoldBackgroundColor', color.value);
    }
    notifyListeners();
  }

  void setCardColor(Color color, bool isDarkMode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (isDarkMode) {
      _darkCardColor = color;
      await prefs.setInt('darkCardColor', color.value);
    } else {
      _lightCardColor = color;
      await prefs.setInt('lightCardColor', color.value);
    }
    notifyListeners();
  }

  void setAppBarBackgroundColor(Color color, bool isDarkMode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (isDarkMode) {
      _darkAppBarBackgroundColor = color;
      await prefs.setInt('darkAppBarBackgroundColor', color.value);
    } else {
      _lightAppBarBackgroundColor = color;
      await prefs.setInt('lightAppBarBackgroundColor', color.value);
    }
    notifyListeners();
  }

  void setSecondaryColor(Color color, bool isDarkMode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (isDarkMode) {
      _darkSecondaryColor = color;
      await prefs.setInt('darkSecondaryColor', color.value);
    } else {
      _lightSecondaryColor = color;
      await prefs.setInt('lightSecondaryColor', color.value);
    }
    notifyListeners();
  }

  void resetColors(bool isDarkMode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (isDarkMode) {
      _darkPrimaryColor = const Color(0xFF673AB7);
      _darkScaffoldBackgroundColor = Colors.black;
      _darkCardColor = const Color(0xFF1C1C1C);
      _darkAppBarBackgroundColor = const Color.fromARGB(255, 0, 0, 0);
      _darkSecondaryColor = const Color.fromARGB(255, 184, 28, 176);

      await prefs.remove('darkPrimaryColor');
      await prefs.remove('darkScaffoldBackgroundColor');
      await prefs.remove('darkCardColor');
      await prefs.remove('darkAppBarBackgroundColor');
      await prefs.remove('darkSecondaryColor');
    } else {
      _lightPrimaryColor = const Color(0xFF673AB7);
      _lightScaffoldBackgroundColor = const Color(0xFF673AB7);
      _lightCardColor = const Color(0xFF673AB7);
      _lightAppBarBackgroundColor = const Color(0xFF673AB7);
      _lightSecondaryColor = const Color(0xFF00BCD4);

      await prefs.remove('lightPrimaryColor');
      await prefs.remove('lightScaffoldBackgroundColor');
      await prefs.remove('lightCardColor');
      await prefs.remove('lightAppBarBackgroundColor');
      await prefs.remove('lightSecondaryColor');
    }
    notifyListeners();
  }
}

class ThemeCustomizationScreen extends StatelessWidget {
  const ThemeCustomizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تخصيص الألوان'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildColorPickerListTile(
            context,
            'اللون الأساسي',
            themeProvider.getPrimaryColor(isDarkMode),
            (color) => themeProvider.setPrimaryColor(color, isDarkMode),
          ),
          _buildColorPickerListTile(
            context,
            'لون خلفية التطبيق',
            themeProvider.getScaffoldBackgroundColor(isDarkMode),
            (color) =>
                themeProvider.setScaffoldBackgroundColor(color, isDarkMode),
          ),
          _buildColorPickerListTile(
            context,
            'لون البطاقات',
            themeProvider.getCardColor(isDarkMode),
            (color) => themeProvider.setCardColor(color, isDarkMode),
          ),
          _buildColorPickerListTile(
            context,
            'لون شريط التطبيق',
            themeProvider.getAppBarBackgroundColor(isDarkMode),
            (color) =>
                themeProvider.setAppBarBackgroundColor(color, isDarkMode),
          ),
          _buildColorPickerListTile(
            context,
            'اللون الثانوي',
            themeProvider.getSecondaryColor(isDarkMode),
            (color) => themeProvider.setSecondaryColor(color, isDarkMode),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false)
                  .resetColors(isDarkMode);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 4.0,
            ),
            child: const Text(
              'إعادة تعيين الألوان',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPickerListTile(BuildContext context, String title,
      Color currentColor, Function(Color) onColorSelected) {
    return ListTile(
      title: Text(title),
      trailing: ColorIndicator(
        width: 44,
        height: 44,
        borderRadius: 22,
        color: currentColor,
        elevation: 4.0,
        onSelect: () async {
          // Store the original color in case the user cancels
          final Color colorBeforeDialog = currentColor;

          bool? result = await ColorPicker(
            color: currentColor,
            onColorChanged: onColorSelected,
            title: Text('اختر لونًا لـ \$title'),
            pickersEnabled: const <ColorPickerType, bool>{
              ColorPickerType.both: false,
              ColorPickerType.primary: true,
              ColorPickerType.accent: true,
              ColorPickerType.bw: false,
              ColorPickerType.custom: false,
              ColorPickerType.wheel: true,
            },
            enableOpacity: true,
            colorCodeHasColor: true,
            showColorCode: true,
            copyPasteBehavior:
                const ColorPickerCopyPasteBehavior(longPressMenu: true),
          ).showPickerDialog(
            context,
            transitionBuilder: (BuildContext context, Animation<double> a1,
                Animation<double> a2, Widget widget) {
              final double curvedValue =
                  Curves.easeInOutBack.transform(a1.value) - 1.0;
              return Transform(
                transform:
                    Matrix4.translationValues(0.0, curvedValue * 200, 0.0),
                child: Opacity(
                  opacity: a1.value,
                  child: widget,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
            constraints: const BoxConstraints(
                minHeight: 460, minWidth: 300, maxWidth: 320),
          );

          // If the user canceled the dialog, revert to the original color
          if (result == false) {
            onColorSelected(colorBeforeDialog);
          }
        },
      ),
    );
  }
}
