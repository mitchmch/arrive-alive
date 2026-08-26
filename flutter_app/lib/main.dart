import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'core/mapbox_config.dart';
import 'core/access_policy.dart';
import 'controllers/auth_controller.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'services/connectivity_service.dart';
import 'services/local_database.dart';
import 'screens/access_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/travel_flow_screen.dart';
import 'screens/journey_screen.dart';
import 'screens/scoreboard_screen.dart';
import 'screens/report_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/bottom_nav.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure Mapbox before any native map object can be constructed.
  MapboxConfig.ensureInitialized();

  _initServices();
  runApp(const ProviderScope(child: ArriveAliveApp()));
}

Future<void> _initServices() async {
  // Initialize local database
  try {
    await LocalDatabase().database;
  } catch (_) {}

  // Initialize connectivity monitoring and sync service
  try {
    final connectivity = ConnectivityService();
    connectivity.init();
    final sync = SyncService();
    sync.init();
  } catch (_) {}
}

class ArriveAliveApp extends ConsumerStatefulWidget {
  const ArriveAliveApp({super.key});

  @override
  ConsumerState<ArriveAliveApp> createState() => _ArriveAliveAppState();
}

class _ArriveAliveAppState extends ConsumerState<ArriveAliveApp> {
  int _navIndex = 0; // Every authenticated user lands on the journey map.
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    try {
      await NotificationService.init();
    } catch (_) {
      // Firebase not configured yet — app still works
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return MaterialApp(
      title: 'Arrive Alive',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: _showSplash
          ? SplashScreen(
              onComplete: () {
                setState(() => _showSplash = false);
              },
            )
          : _buildHome(auth),
      routes: {
        '/register': (_) => const RegisterScreen(),
        '/login': (_) => const LoginScreen(),
        '/travel': (_) => const TravelFlowScreen(),
        '/journey': (_) => const JourneyScreen(),
        '/scoreboard': (_) => const ScoreboardScreen(),
        '/report': (_) => const ReportScreen(),
        '/admin': (_) => const AdminScreen(),
        '/history': (_) => const HistoryScreen(),
        '/profile': (_) => const ProfileScreen(),
      },
    );
  }

  Widget _buildHome(AuthState auth) {
    if (AccessPolicy.landingFor(auth.user) == AppLanding.access) {
      return const AccessScreen();
    }

    // Guests get the complete journey, navigation, reporting, and hazard
    // confirmation experience without professional scoreboard access.
    if (auth.user!.isGuest) {
      return const JourneyScreen();
    }

    // Logged in user
    Widget body;
    switch (_navIndex) {
      case 0:
        body = const JourneyScreen();
        break;
      case 1:
        body = const ScoreboardScreen();
        break;
      case 2:
        body = const ReportScreen();
        break;
      case 3:
        body = const HistoryScreen();
        break;
      case 4:
        body = AccessPolicy.canAccessAdmin(auth.user)
            ? const AdminScreen()
            : const JourneyScreen();
        break;
      default:
        body = const ScoreboardScreen();
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNav(
        currentIndex: _navIndex,
        role: auth.user!.role,
        isGuest: false,
        onTap: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}
