import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/lookup_provider.dart';
import 'providers/family_provider.dart';
import 'providers/tracking_provider.dart';
import 'providers/financial_provider.dart';
import 'providers/search_provider.dart';
import 'providers/settings_provider.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/family/family_list_screen.dart';
import 'ui/screens/family/family_form_screen.dart';
import 'ui/screens/areas/areas_screen.dart';
import 'ui/screens/fathers/fathers_screen.dart';
import 'ui/screens/lookups/stages_screen.dart';
import 'ui/screens/lookups/stage_promotion_screen.dart';
import 'ui/screens/lookups/services_screen.dart';
import 'ui/screens/lookups/lookup_management_screen.dart';
import 'ui/screens/tracking/occasions_screen.dart';
import 'ui/screens/reports/birthdays_screen.dart';
import 'ui/screens/reports/main_report_screen.dart';
import 'ui/screens/tracking/confession_screen.dart';
import 'ui/screens/tracking/visit_screen.dart';
import 'ui/screens/financial/aid_screen.dart';
import 'ui/screens/financial/expense_screen.dart';
import 'ui/screens/search/search_screen.dart';
import 'ui/screens/users/users_screen.dart';
import 'ui/screens/id_card/id_card_generator_screen.dart';
import 'sync/server_connection_service.dart';
import 'sync/signalr_sync_service.dart';
import 'sync/data_sync_coordinator.dart';

import 'package:liquidify/liquidify.dart';
import 'ui/theme/app_theme.dart';

class ChurchMembershipApp extends StatelessWidget {
  const ChurchMembershipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LookupProvider()),
        ChangeNotifierProvider(create: (_) => FamilyProvider()),
        ChangeNotifierProvider(create: (_) => TrackingProvider()),
        ChangeNotifierProvider(create: (_) => FinancialProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ServerConfigProvider()),
        ChangeNotifierProvider(create: (_) => SignalRSyncProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final isDark = settings.isDarkMode;
          final glassOptions = AppTheme.getLiquidGlassOptions(
            isDark: isDark,
            primaryColor: settings.primaryColor,
          );

          return LiquidGlassTheme(
            options: glassOptions,
            child: DataSyncCoordinator(
              child: MaterialApp(
                title: 'Church Membership - العضوية الكنسية',
                debugShowCheckedModeBanner: false,
                themeMode: settings.themeMode,
                theme: AppTheme.buildLightTheme(settings.primaryColor),
                darkTheme: AppTheme.buildDarkTheme(settings.primaryColor),
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AuthWrapper(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const HomeScreen(),
            '/family-list': (context) => const FamilyListScreen(),
            '/family-form': (context) => const FamilyFormScreen(),
            '/areas': (context) => const AreasScreen(),
            '/fathers': (context) => const FathersScreen(),
            '/stages': (context) => const StagesScreen(),
            '/promote-stages': (context) => const StagesPromotionScreen(),
            '/services': (context) => const ServicesScreen(),
            '/occasions': (context) => const OccasionsScreen(),
            '/birthdays': (context) => const BirthdaysScreen(),
            '/report': (context) => const MainReportScreen(),
            '/confession': (context) => const ConfessionScreen(),
            '/visit': (context) => const VisitScreen(),
            '/aid': (context) => const AidScreen(),
            '/expense': (context) => const ExpenseScreen(),
            '/search': (context) => const SearchScreen(),
            '/users': (context) => const UsersScreen(),
            '/lookups': (context) => const LookupManagementScreen(),
            '/id-cards': (context) => const IdCardGeneratorScreen(),
          },
              ),
            ),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (auth.currentUser == null) {
      return const LoginScreen();
    }
    return const HomeScreen();
  }
}
