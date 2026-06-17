import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'database/database_helper.dart';
import 'services/schedule_import_service.dart';
import 'services/user_service.dart';
import 'utils/seed_data.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');

  final autoLoginUser = await UserService.getAutoLoginUser();
  final currentUser = await UserService.getCurrentUsername();
  final effectiveUser = autoLoginUser ?? currentUser;

  if (effectiveUser != null) {
    await DatabaseHelper.switchUser(effectiveUser);
    final importResult = await ScheduleImportService.importBundleIfNeeded(effectiveUser);
    if (kDebugMode && importResult != null) {
      debugPrint('ScheduleImportService: $importResult');
    }
  }

  if (kDebugMode) {
    await seedTestData();
  }
  runApp(PaiqiApp(initialUser: effectiveUser));
}

class PaiqiApp extends StatelessWidget {
  final String? initialUser;
  const PaiqiApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '排期助手',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'CN'),
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6B5BCD),
          onPrimary: Colors.white,
          secondary: Color(0xFF811FE2),
          onSecondary: Colors.white,
          surface: Color(0xFF181818),
          onSurface: Color(0xFFFFFFFF),
          surfaceContainerHighest: Color(0xFF252525),
          onSurfaceVariant: Color(0xFFB3B3B3),
          error: Color(0xFFF54A45),
          onError: Colors.white,
          outline: Color(0xFF4D4D4D),
        ),
        useMaterial3: true,
        fontFamily: 'NotoSansSC',
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF181818),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          shadowColor: Colors.black,
        ),
        filledButtonTheme: const FilledButtonThemeData(
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(StadiumBorder()),
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ),
        outlinedButtonTheme: const OutlinedButtonThemeData(
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(StadiumBorder()),
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            side: WidgetStatePropertyAll(
              BorderSide(color: Color(0xFF4D4D4D)),
            ),
          ),
        ),
        textButtonTheme: const TextButtonThemeData(
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(StadiumBorder()),
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        elevatedButtonTheme: const ElevatedButtonThemeData(
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(StadiumBorder()),
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            backgroundColor: WidgetStatePropertyAll(Color(0xFF1F1F1F)),
            foregroundColor: WidgetStatePropertyAll(Colors.white),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF121212),
          foregroundColor: Color(0xFFFFFFFF),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF121212),
          selectedItemColor: Color(0xFFFFFFFF),
          unselectedItemColor: Color(0xFFB3B3B3),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          indicatorColor: Colors.transparent,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: isSelected
                  ? const Color(0xFF6B5BCD)
                  : const Color(0xFFB3B3B3),
              size: 24,
              shadows: isSelected
                  ? [
                      Shadow(
                        color: const Color(0xFF6B5BCD).withValues(alpha: 0.8),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              color: isSelected
                  ? const Color(0xFF6B5BCD)
                  : const Color(0xFFB3B3B3),
              fontSize: 12,
              shadows: isSelected
                  ? [
                      Shadow(
                        color: const Color(0xFF6B5BCD).withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            );
          }),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF181818),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF181818),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1F1F1F),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF4D4D4D)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF4D4D4D)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF6B5BCD)),
          ),
          labelStyle: const TextStyle(color: Color(0xFFB3B3B3)),
          hintStyle: const TextStyle(color: Color(0xFF7C7C7C)),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF1F1F1F),
          selectedColor: const Color(0xFF6B5BCD),
          labelStyle: const TextStyle(color: Color(0xFFFFFFFF)),
          secondaryLabelStyle: const TextStyle(color: Color(0xFFFFFFFF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(500),
            side: const BorderSide(color: Color(0xFF4D4D4D)),
          ),
        ),
        textTheme: const TextTheme(
          titleMedium: TextStyle(color: Color(0xFFFFFFFF)),
          bodyLarge: TextStyle(color: Color(0xFFFFFFFF)),
          bodyMedium: TextStyle(color: Color(0xFFB3B3B3)),
          bodySmall: TextStyle(color: Color(0xFF8A8F98)),
        ),
      ),
      home: initialUser != null ? const MainScreen() : const LoginScreen(),
    );
  }
}
