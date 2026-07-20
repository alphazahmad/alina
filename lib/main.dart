import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/namaz_service.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/home_tab.dart';
import 'widgets/islamic_hub.dart';
import 'widgets/finance_dashboard.dart';
import 'widgets/tasks_tab.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseInitialized = false;

  try {
    await Firebase.initializeApp();
    firebaseInitialized = true;
  } catch (e) {
    debugPrint('Native Firebase init skipped: $e');
  }

  if (!firebaseInitialized) {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options != null) {
      try {
        await Firebase.initializeApp(options: options);
        firebaseInitialized = true;
      } catch (e) {
        debugPrint('Dart Firebase options init failed: $e');
      }
    }
  }

  if (firebaseInitialized) {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (_) {}
  } else {
    debugPrint('Running in Local Sandbox Mode.');
  }

  runApp(const AlinaApp());
}

// ─── Theme Persistence ─────────────────────────────────────────────────────
Future<void> saveThemeMode(ThemeMode mode) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    await File('${dir.path}/theme_mode.txt').writeAsString(mode.toString());
  } catch (_) {}
}

Future<ThemeMode> loadThemeMode() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/theme_mode.txt');
    if (await file.exists()) {
      final c = await file.readAsString();
      if (c == ThemeMode.light.toString()) return ThemeMode.light;
      if (c == ThemeMode.dark.toString()) return ThemeMode.dark;
    }
  } catch (_) {}
  return ThemeMode.system;
}

// ─── App Root ──────────────────────────────────────────────────────────────
class AlinaApp extends StatefulWidget {
  const AlinaApp({super.key});

  @override
  State<AlinaApp> createState() => _AlinaAppState();
}

class _AlinaAppState extends State<AlinaApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    loadThemeMode().then((m) => setState(() => _themeMode = m));
  }

  void _changeTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
    saveThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFF52670);
    return MaterialApp(
      title: 'Alina',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light, primary: seed),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark, primary: seed),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
      ),
      home: AuthGate(onChangeTheme: _changeTheme, themeMode: _themeMode),
    );
  }
}

// ─── Auth Gate ─────────────────────────────────────────────────────────────
class AuthGate extends StatelessWidget {
  final ValueChanged<ThemeMode> onChangeTheme;
  final ThemeMode themeMode;

  const AuthGate({super.key, required this.onChangeTheme, required this.themeMode});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    WidgetsBinding.instance.addPostFrameCallback((_) => authService.triggerInitialState());

    return StreamBuilder<AuthUser?>(
      stream: authService.onAuthStateChanged,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFF52670))));
        }
        final user = snapshot.data;
        if (user != null) {
          return HomeScreen(user: user, onChangeTheme: onChangeTheme, themeMode: themeMode);
        }
        return const LoginScreen();
      },
    );
  }
}

// ─── Home Screen ────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  final AuthUser user;
  final ValueChanged<ThemeMode> onChangeTheme;
  final ThemeMode themeMode;

  const HomeScreen({super.key, required this.user, required this.onChangeTheme, required this.themeMode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _namazService = NamazService();
  int _currentIndex = 0;

  // Home tab data
  Map<String, Map<String, dynamic>> _last7DaysRecords = {};
  int _relationshipLevel = 1;
  int _lovePoints = 10;
  String _alinaMood = 'Happy 💖';
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _triggerAutoSync();
  }

  void _triggerAutoSync() {
    SyncManager().syncAll(widget.user.uid).then((result) {
      debugPrint('Startup auto-sync completed: ${result.message}');
    }).catchError((e) {
      debugPrint('Startup auto-sync error: $e');
    });
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    try {
      // Fetch stats concurrently
      final results = await Future.wait([
        _namazService.getDayRecord(widget.user.uid, DateTime.now()),
        _namazService.getStatsSummary(widget.user.uid),
      ]);

      final stats = results[1];
      if (mounted) {
        setState(() {
          _relationshipLevel = stats['relationshipLevel'] ?? 1;
          _lovePoints = stats['lovePoints'] ?? 10;
          _alinaMood = stats['alinaMood'] ?? 'Happy 💖';
          _isLoadingData = false;
        });
      }

      // Background: load last 7 days
      final now = DateTime.now();
      final datesToFetch = <DateTime>[];
      for (int i = 0; i <= 6; i++) {
        final d = now.subtract(Duration(days: i));
        if (!d.isBefore(NamazService.startDate)) datesToFetch.add(d);
      }

      final dayRecords = await Future.wait(
        datesToFetch.map((d) => _namazService.getDayRecord(widget.user.uid, d)),
      );

      final Map<String, Map<String, dynamic>> last7 = {};
      for (int i = 0; i < datesToFetch.length; i++) {
        last7[_namazService.formatDate(datesToFetch[i])] = dayRecords[i];
      }

      if (mounted) setState(() => _last7DaysRecords = last7);
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  // ─── Titles per tab ──────────────────────────────────────────────
  static const _titles = ['Home', 'Islamic', 'Finance', 'Tasks', 'Profile'];
  static const _titleIcons = [
    Icons.home_outlined,
    Icons.mosque_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.checklist_rounded,
    Icons.person_outline,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        leadingWidth: 0,
        title: Row(
          children: [
            Icon(_titleIcons[_currentIndex], color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              _titles[_currentIndex],
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : const Color(0xFF1A0010)),
            ),
          ],
        ),
        actions: [
          if (_currentIndex == 0)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: AuthService().isSandboxMode ? Colors.orange : Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    AuthService().isSandboxMode ? 'Local' : 'Synced',
                    style: TextStyle(fontSize: 11, color: AuthService().isSandboxMode ? Colors.orange : Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingData
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFF52670)))
            : IndexedStack(
                index: _currentIndex,
                children: [
                  // Tab 0 – Home
                  HomeTab(
                    uid: widget.user.uid,
                    relationshipLevel: _relationshipLevel,
                    lovePoints: _lovePoints,
                    alinaMood: _alinaMood,
                    last7DaysRecords: _last7DaysRecords,
                    isLoading: _isLoadingData,
                    onRefresh: _loadUserData,
                  ),
                  // Tab 1 – Islamic (Namaz + Zikr + Namaz Calendar)
                  IslamicHub(uid: widget.user.uid),
                  // Tab 2 – Finance
                  FinanceDashboard(uid: widget.user.uid),
                  // Tab 3 – Tasks (To-Do + Smart Calendar)
                  TasksTab(uid: widget.user.uid),
                  // Tab 4 – Profile
                  ProfileScreen(
                    uid: widget.user.uid,
                    email: widget.user.email,
                    themeMode: widget.themeMode,
                    onChangeTheme: widget.onChangeTheme,
                    isSandboxMode: AuthService().isSandboxMode,
                  ),
                ],
              ),
      ),
      bottomNavigationBar: _buildNavBar(theme, isDark),
    );
  }

  Widget _buildNavBar(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(top: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.08))),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Home', theme, isDark),
              _navItem(1, Icons.mosque_rounded, Icons.mosque_outlined, 'Islamic', theme, isDark),
              _navItem(2, Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Finance', theme, isDark),
              _navItem(3, Icons.checklist_rounded, Icons.checklist_outlined, 'Tasks', theme, isDark),
              _navItem(4, Icons.person_rounded, Icons.person_outline, 'Profile', theme, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData selIcon, IconData unselIcon, String label, ThemeData theme, bool isDark) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 14 : 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selIcon : unselIcon,
              color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white38 : Colors.grey.shade500),
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            ],
          ],
        ),
      ),
    );
  }
}
