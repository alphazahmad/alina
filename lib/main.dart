import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/namaz_service.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/wellness_hub.dart';
import 'widgets/home_tab.dart';
import 'widgets/islamic_hub.dart';
import 'widgets/tasks_tab.dart';
import 'services/sync_service.dart';
import 'screens/alina_chat_sheet.dart';

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
    return MaterialApp(
      title: 'Alina',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
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
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
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
      // Recalculate 7-day relationship stats on startup to keep Alina reactive
      await _namazService.recalculateRelationshipStats(widget.user.uid);

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

  // ─── Tab Configuration ──────────────────────────────────────────────
  static const _titles = ['Home', 'Chat', 'Tasks', 'Islamic', 'More'];
  static const _tabIcons = [
    Icons.home_rounded,
    Icons.chat_bubble_rounded,
    Icons.checklist_rounded,
    Icons.mosque_rounded,
    Icons.more_horiz_rounded,
  ];
  static const _tabIconsOutlined = [
    Icons.home_outlined,
    Icons.chat_bubble_outline_rounded,
    Icons.checklist_outlined,
    Icons.mosque_outlined,
    Icons.more_horiz_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // extendBody is FALSE so the nav bar does NOT overlap content.
      // The nav bar sits inside SafeArea so nothing gets clipped.
      body: SafeArea(
        bottom: false, // nav bar handles its own safe area inset
        child: _isLoadingData
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Column(
                children: [
                  // ─── Minimal Header ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Row(
                      children: [
                        Text(
                          _titles[_currentIndex],
                          style: AppTextStyles.heading(isDark),
                        ),
                        const Spacer(),

                        // ── Sync badge (Home tab only) ──────────────
                        if (_currentIndex == 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: (AuthService().isSandboxMode
                                      ? AppColors.expense
                                      : AppColors.income)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: AuthService().isSandboxMode
                                      ? AppColors.expense
                                      : AppColors.income,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  AuthService().isSandboxMode ? 'Local' : 'Synced',
                                  style: AppTextStyles.caption(isDark).copyWith(
                                    color: AuthService().isSandboxMode
                                        ? AppColors.expense
                                        : AppColors.income,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Notification bell
                          _buildHeaderIcon(
                            Icons.notifications_none_rounded,
                            isDark,
                            onTap: () {/* TODO: notifications */},
                          ),
                        ],

                        // ── New chat icon (Chat tab only) ───────────
                        if (_currentIndex == 1)
                          _buildHeaderIcon(
                            Icons.edit_note_rounded,
                            isDark,
                            onTap: () {/* TODO: new chat */},
                          ),

                        // ── Profile icon (More/Wellness tab only) ───
                        if (_currentIndex == 4)
                          _buildHeaderIcon(
                            Icons.person_outline_rounded,
                            isDark,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfileScreen(
                                    uid: widget.user.uid,
                                    email: widget.user.email,
                                    themeMode: widget.themeMode,
                                    onChangeTheme: widget.onChangeTheme,
                                    isSandboxMode: AuthService().isSandboxMode,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  // ─── Content ─────────────────────────────────────────
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: [
                        HomeTab(
                          uid: widget.user.uid,
                          relationshipLevel: _relationshipLevel,
                          lovePoints: _lovePoints,
                          alinaMood: _alinaMood,
                          last7DaysRecords: _last7DaysRecords,
                          isLoading: _isLoadingData,
                          onRefresh: _loadUserData,
                          onTabSelected: (index) {
                            setState(() => _currentIndex = index);
                          },
                          themeMode: widget.themeMode,
                          onChangeTheme: widget.onChangeTheme,
                          email: widget.user.email,
                        ),
                        AlinaChatSheet(uid: widget.user.uid, embedded: true),
                        TasksTab(uid: widget.user.uid),
                        IslamicHub(uid: widget.user.uid),
                        WellnessHub(
                          uid: widget.user.uid,
                          themeMode: widget.themeMode,
                          onChangeTheme: widget.onChangeTheme,
                          email: widget.user.email,
                        ),
                      ],
                    ),
                  ),

                  // ─── Floating Bottom Navigation (INSIDE body) ────────
                  _buildFloatingNav(theme, isDark),
                ],
              ),
      ),
    );
  }

  /// Compact icon button used in the header bar.
  Widget _buildHeaderIcon(IconData icon, bool isDark, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  FLOATING GLASSMORPHISM BOTTOM NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildFloatingNav(ThemeData theme, bool isDark) {
    // Use viewPadding (safe-area inset) to sit just above the system gesture bar.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: bottomInset > 0 ? bottomInset + 6 : 12,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            height: 64,
            decoration: AppDecoration.floatingNav(isDark),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (i) => _buildNavItem(i, theme, isDark)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, ThemeData theme, bool isDark) {
    final isSelected = _currentIndex == index;
    final icon = isSelected ? _tabIcons[index] : _tabIconsOutlined[index];
    final label = _titles[index];

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: AppColors.primaryGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.0 : 0.9,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white38 : Colors.grey.shade400),
                size: 22,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.navLabel().copyWith(color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
