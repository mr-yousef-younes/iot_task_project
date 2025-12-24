import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iot_pulse/history_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'home.dart';
import 'settings_screen.dart';

Future<void> requestAllPermissions() async {
  await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
  ].request();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestAllPermissions();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: const IoTPulse(),
    ),
  );
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const DashboardPage()),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/history/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return HistoryScreen(userId: userId);
      },
    ),
  ],
);

class IoTPulse extends StatelessWidget {
  const IoTPulse({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      title: 'IoT Pulse',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        textTheme: GoogleFonts.cairoTextTheme(),
      ),
    );
  }
}

class AppSettings extends ChangeNotifier {
  bool _isFahrenheit = false;
  String? _userId;

  bool get isFahrenheit => _isFahrenheit;
  String? get userId => _userId;

  void toggleUnit(bool value) {
    _isFahrenheit = value;
    notifyListeners();
  }

  void setUserId(String? id) {
    _userId = id;
    notifyListeners();
  }
}
