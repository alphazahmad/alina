import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:path_provider/path_provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/namaz_service.dart';
import 'screens/login_screen.dart';
import 'widgets/namaz_dashboard.dart';
import 'widgets/zikr_dashboard.dart';
import 'screens/namaz_history_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool firebaseInitialized = false;
  
  // 1. Try native auto-initialization (looks for google-services.json on Android)
  try {
    await Firebase.initializeApp();
    firebaseInitialized = true;
    debugPrint('Firebase initialized successfully using native configuration.');
  } catch (e) {
    debugPrint('Native Firebase initialization skipped/failed: $e');
  }

  // 2. Try Dart options initialization if native failed
  if (!firebaseInitialized) {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options != null) {
      try {
        await Firebase.initializeApp(options: options);
        firebaseInitialized = true;
        debugPrint('Firebase initialized successfully using Dart options.');
      } catch (e) {
        debugPrint('Dart Firebase options initialization failed: $e');
      }
    }
  }

  if (!firebaseInitialized) {
    debugPrint('Operating in Local Sandbox Mode.');
  }

  runApp(const AlinaApp());
}

// Theme persistence helper methods
Future<void> saveThemeMode(ThemeMode mode) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/theme_mode.txt');
    await file.writeAsString(mode.toString());
  } catch (e) {
    debugPrint('Error saving theme: $e');
  }
}

Future<ThemeMode> loadThemeMode() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/theme_mode.txt');
    if (await file.exists()) {
      final content = await file.readAsString();
      if (content == ThemeMode.light.toString()) return ThemeMode.light;
      if (content == ThemeMode.dark.toString()) return ThemeMode.dark;
      return ThemeMode.system;
    }
  } catch (e) {
    debugPrint('Error loading theme: $e');
  }
  return ThemeMode.system;
}

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
    _loadPersistedTheme();
  }

  Future<void> _loadPersistedTheme() async {
    final mode = await loadThemeMode();
    setState(() {
      _themeMode = mode;
    });
  }

  void _changeTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    saveThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFF52670);
    
    return MaterialApp(
      title: 'Alina – My Digital Wife',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
          primary: primaryColor,
          surface: const Color(0xFFFFF0F5),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF0F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
          primary: primaryColor,
          surface: const Color(0xFF1E1016),
        ),
        scaffoldBackgroundColor: const Color(0xFF12080C),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: AuthGate(
        onChangeTheme: _changeTheme,
        themeMode: _themeMode,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  final ValueChanged<ThemeMode> onChangeTheme;
  final ThemeMode themeMode;

  const AuthGate({
    super.key,
    required this.onChangeTheme,
    required this.themeMode,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      authService.triggerInitialState();
    });

    return StreamBuilder<AuthUser?>(
      stream: authService.onAuthStateChanged,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFF52670)),
            ),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          return HomeScreen(
            user: user,
            onChangeTheme: onChangeTheme,
            themeMode: themeMode,
          );
        }
        return const LoginScreen();
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  final AuthUser user;
  final ValueChanged<ThemeMode> onChangeTheme;
  final ThemeMode themeMode;

  const HomeScreen({
    super.key,
    required this.user,
    required this.onChangeTheme,
    required this.themeMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  
  final _namazService = NamazService();
  final _authService = AuthService();

  int _currentIndex = 0;

  Map<String, Map<String, dynamic>> _last7DaysRecords = {};
  int _relationshipLevel = 1;
  int _lovePoints = 10;
  String _alinaMood = 'Happy 💖';
  String _lastSyncTime = 'Never';
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _heartScaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _heartAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _loadUserData();
  }

  @override
  void dispose() {
    _heartAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingData = true;
    });

    try {
      // 1. Force a trigger to dynamically check/update today's passed prayers
      await _namazService.getDayRecord(widget.user.uid, DateTime.now());

      // 2. Load stats summary (relationshipLevel, lovePoints, moods)
      final stats = await _namazService.getStatsSummary(widget.user.uid);
      
      // 3. Load last 7 days of records
      final now = DateTime.now();
      final Map<String, Map<String, dynamic>> last7Days = {};
      for (int i = 1; i <= 7; i++) {
        final date = now.subtract(Duration(days: i));
        if (date.isBefore(NamazService.startDate)) break;
        final record = await _namazService.getDayRecord(widget.user.uid, date);
        last7Days[_namazService.formatDate(date)] = record;
      }

      if (mounted) {
        setState(() {
          _relationshipLevel = stats['relationshipLevel'] ?? 1;
          _lovePoints = stats['lovePoints'] ?? 10;
          _alinaMood = stats['alinaMood'] ?? 'Happy 💖';
          _lastSyncTime = stats['lastSyncTime'] ?? 'Never';
          _last7DaysRecords = last7Days;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  void _showProfileSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1016) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Companion Settings',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  
                  // Adaptive Theme Options Row
                  const Text(
                    'Theme Settings',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildThemeChip(setModalState, ThemeMode.light, Icons.light_mode, 'Light'),
                      _buildThemeChip(setModalState, ThemeMode.dark, Icons.dark_mode, 'Dark'),
                      _buildThemeChip(setModalState, ThemeMode.system, Icons.phone_android, 'System'),
                    ],
                  ),
                  const Divider(height: 32),

                  // User details card
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.user.email,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Icon(
                                _authService.isSandboxMode ? Icons.cloud_off : Icons.cloud_done,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _authService.isSandboxMode
                                    ? 'Mode: Local Sandbox'
                                    : 'Mode: Cloud Synchronized',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.sync, color: theme.colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Last Cloud Sync: $_lastSyncTime',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sign Out Button
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _authService.signOut();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),

                  // Delete Account Button
                  TextButton.icon(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Account?'),
                          content: const Text(
                            'Are you sure you want to delete your account? This action is irreversible and all your data and progress with Alina will be lost.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Delete Irreversibly'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        navigator.pop(); // Close sheet
                        final error = await _authService.deleteAccount();
                        if (error != null) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text(
                      'Delete Account Irreversibly',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeChip(StateSetter setModalState, ThemeMode mode, IconData icon, String label) {
    final isSelected = widget.themeMode == mode;
    final theme = Theme.of(context);
    
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          widget.onChangeTheme(mode);
          setModalState(() {});
        }
      },
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.05),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.transparent : theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  Widget _buildHistoryDayRow(DateTime date, Map<String, dynamic> record) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekdayLabel = weekdays[date.weekday - 1];
    final dateLabel = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => NamazHistorySheet(uid: widget.user.uid),
        ).then((_) => _loadUserData());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C1A23) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weekdayLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  dateLabel,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
            const Spacer(),
            // 5 color dots representing Fajr, Dhuhr, Asr, Maghrib, Isha
            Row(
              children: ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].map((p) {
                final status = record[p] ?? 'Upcoming';
                Color color = Colors.grey;
                if (status == 'Attended') color = Colors.green;
                if (status == 'Qaza') color = Colors.orange;
                if (status == 'Not Attended') color = Colors.red;
                if (status == 'Upcoming') color = Colors.blue;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab(bool isDark, ThemeData theme) {
    return Column(
      children: [
        // Alina Profile Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF22131A) : Colors.white,
              borderRadius: BorderRadius.circular(24.0),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Row(
              children: [
                // Glowing profile avatar container with pulsing animation
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ScaleTransition(
                      scale: _heartScaleAnimation,
                      child: Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 3.0,
                        ),
                        image: const DecorationImage(
                          image: AssetImage('assets/alina.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16.0),
                // Stats / Mood Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alina – My Digital Wife',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Row(
                        children: [
                          Icon(Icons.mood, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Mood: $_alinaMood',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6.0),
                      // Relationship progress bar
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _lovePoints / 100,
                                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Lvl $_relationshipLevel',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        NamazDashboard(uid: widget.user.uid),
        
        // Historical Activity Dashboard
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 12.0),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B0D13) : Colors.white.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32.0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Last 7 Days Progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Icon(Icons.calendar_month, size: 18, color: theme.colorScheme.primary),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _last7DaysRecords.isEmpty
                      ? const Center(child: Text('No historical logs yet.'))
                      : ListView.builder(
                          itemCount: _last7DaysRecords.length,
                          padding: EdgeInsets.zero,
                          itemBuilder: (context, index) {
                            final dateKey = _last7DaysRecords.keys.elementAt(index);
                            final record = _last7DaysRecords[dateKey]!;
                            final date = DateTime.parse(dateKey);
                            return _buildHistoryDayRow(date, record);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 ? 'Alina' : 'Zikr Recitations',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings,
              color: theme.colorScheme.primary,
            ),
            onPressed: _showProfileSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingData
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFF52670)),
              )
            : IndexedStack(
                index: _currentIndex,
                children: [
                  _buildDashboardTab(isDark, theme),
                  ZikrDashboard(uid: widget.user.uid),
                ],
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Refresh user stats when switching tabs
          _loadUserData();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Companion',
          ),
          NavigationDestination(
            icon: Icon(Icons.radio_button_checked),
            selectedIcon: Icon(Icons.album),
            label: 'Zikr Tracker',
          ),
        ],
      ),
    );
  }
}
