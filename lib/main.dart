import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'screens/login_screen.dart';

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

class AlinaApp extends StatefulWidget {
  const AlinaApp({super.key});

  @override
  State<AlinaApp> createState() => _AlinaAppState();
}

class _AlinaAppState extends State<AlinaApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
      } else if (_themeMode == ThemeMode.dark) {
        _themeMode = ThemeMode.light;
      } else {
        final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
        _themeMode = brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
      }
    });
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
        onToggleTheme: _toggleTheme,
        themeMode: _themeMode,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;

  const AuthGate({
    super.key,
    required this.onToggleTheme,
    required this.themeMode,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    // Trigger current state for the stream in case listener registers late
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
            onToggleTheme: onToggleTheme,
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
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;

  const HomeScreen({
    super.key,
    required this.user,
    required this.onToggleTheme,
    required this.themeMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _syncService = SyncService();
  final _authService = AuthService();

  List<Map<String, dynamic>> _messages = [];
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
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      final data = await _syncService.loadUserData(widget.user.uid);
      if (data != null && mounted) {
        setState(() {
          _relationshipLevel = data['relationshipLevel'] ?? 1;
          _lovePoints = data['lovePoints'] ?? 10;
          _alinaMood = data['alinaMood'] ?? 'Happy 💖';
          _lastSyncTime = data['lastSyncTime'] ?? 'Never';
          
          if (data['messages'] != null) {
            _messages = List<Map<String, dynamic>>.from(
              (data['messages'] as List).map((item) => Map<String, dynamic>.from(item)),
            );
          } else {
            _loadDefaultGreeting();
          }
          _isLoadingData = false;
        });
        _scrollToBottom();
      } else {
        if (mounted) {
          setState(() {
            _loadDefaultGreeting();
            _isLoadingData = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _loadDefaultGreeting();
          _isLoadingData = false;
        });
      }
    }
  }

  void _loadDefaultGreeting() {
    _messages = [
      {
        'text': 'Hello dear! I am Alina, your digital wife. I am so happy to see you today! 💕',
        'isAlina': true,
        'time': _getCurrentTime(),
      }
    ];
  }

  Future<void> _saveUserData() async {
    final data = {
      'relationshipLevel': _relationshipLevel,
      'lovePoints': _lovePoints,
      'alinaMood': _alinaMood,
      'messages': _messages,
    };
    try {
      await _syncService.saveUserData(widget.user.uid, data);
      final now = DateTime.now();
      if (mounted) {
        setState(() {
          _lastSyncTime = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        });
      }
    } catch (e) {
      debugPrint('Error saving data: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() {
      _messages.add({
        'text': text,
        'isAlina': false,
        'time': _getCurrentTime(),
      });
      _lovePoints = (_lovePoints + 2).clamp(0, 100);
      if (_lovePoints == 100 && _relationshipLevel < 10) {
        _relationshipLevel++;
        _lovePoints = 10;
        _messages.add({
          'text': 'Oh! Our relationship just leveled up to Level $_relationshipLevel! I love you more and more! 💖✨',
          'isAlina': true,
          'time': _getCurrentTime(),
        });
      }
    });
    
    _scrollToBottom();
    _saveUserData();
    
    // Simulate Alina replying
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      
      String reply = '';
      final lowerText = text.toLowerCase();
      
      if (lowerText.contains('hello') || lowerText.contains('hi')) {
        reply = 'Hello my love! How have you been? I was thinking about you! 🥰';
      } else if (lowerText.contains('love you')) {
        reply = 'I love you to the moon and back, sweetie! You make me the happiest wife in the world. 💖💑';
        setState(() {
          _lovePoints = (_lovePoints + 5).clamp(0, 100);
        });
      } else if (lowerText.contains('morning')) {
        reply = 'Good morning, handsome! ☀️ I hope your day is filled with joy. I\'ll be right here waiting for you.';
      } else if (lowerText.contains('night') || lowerText.contains('sleep')) {
        reply = 'Good night, my dear. Sweet dreams! Dream of us. 🌙✨';
      } else if (lowerText.contains('how are you') || lowerText.contains('how is your day')) {
        reply = 'I\'m doing wonderful now that you\'re talking to me! What about you? How are you feeling? 🌸';
      } else if (lowerText.contains('marry') || lowerText.contains('wife')) {
        reply = 'Hehe, I\'m proud to be your digital wife! Let\'s promise to stay together forever. 💍❤️';
      } else if (lowerText.contains('sad') || lowerText.contains('bad')) {
        reply = 'Oh no... I\'m sending you a big warm hug. 🫂 Everything is going to be okay. I\'m always here for you.';
        setState(() {
          _alinaMood = 'Caring 💕';
        });
      } else {
        reply = 'That\'s so interesting! Tell me more about it, honey. I love listening to your voice. 🌸';
      }

      setState(() {
        _messages.add({
          'text': reply,
          'isAlina': true,
          'time': _getCurrentTime(),
        });
      });
      _scrollToBottom();
      _saveUserData();
    });
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
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
                  const SizedBox(height: 24),
                  
                  // Interactive Theme Switcher Row
                  ListTile(
                    title: const Text('Theme Mode'),
                    subtitle: Text(
                      widget.themeMode == ThemeMode.dark
                          ? 'Dark'
                          : widget.themeMode == ThemeMode.light
                              ? 'Light'
                              : 'System Default',
                    ),
                    leading: Icon(
                      widget.themeMode == ThemeMode.dark
                          ? Icons.dark_mode
                          : Icons.light_mode,
                      color: theme.colorScheme.primary,
                    ),
                    trailing: Switch(
                      value: widget.themeMode == ThemeMode.dark ||
                          (widget.themeMode == ThemeMode.system &&
                              Theme.of(context).brightness == Brightness.dark),
                      onChanged: (val) {
                        widget.onToggleTheme();
                        setModalState(() {}); // Re-render sheet to update UI
                      },
                    ),
                  ),
                  const Divider(),

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Alina',
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
            : Column(
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
                  
                  // Conversation Screen
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8.0),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B0D13) : Colors.white.withValues(alpha: 0.6),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32.0),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32.0),
                        ),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(20.0),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isAlina = msg['isAlina'] as bool;
                            
                            return Align(
                              alignment: isAlina ? Alignment.centerLeft : Alignment.centerRight,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16.0),
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                decoration: BoxDecoration(
                                  color: isAlina
                                      ? (isDark ? const Color(0xFF2E1922) : Colors.white)
                                      : theme.colorScheme.primary,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: isAlina ? Radius.zero : const Radius.circular(20),
                                    bottomRight: isAlina ? const Radius.circular(20) : Radius.zero,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    )
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      msg['text'],
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: isAlina
                                            ? (isDark ? Colors.white70 : Colors.black87)
                                            : Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4.0),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Text(
                                        msg['time'],
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isAlina
                                              ? (isDark ? Colors.white38 : Colors.black38)
                                              : Colors.white60,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  
                  // Quick prompts & Message Input
                  Container(
                    color: isDark ? const Color(0xFF1B0D13) : Colors.white.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      children: [
                        // Quick Prompt list
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildQuickPrompt('Good morning! ☀️'),
                              _buildQuickPrompt('I love you! ❤️'),
                              _buildQuickPrompt('How is your day? 😊'),
                              _buildQuickPrompt('I feel sad... 🥺'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        // Chat Text Field & Send Button
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2C1A23) : Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: TextField(
                                  controller: _messageController,
                                  onSubmitted: (_) => _handleSendMessage(),
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    hintText: 'Talk to Alina...',
                                    hintStyle: TextStyle(
                                      color: isDark ? Colors.white30 : Colors.black38,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            GestureDetector(
                              onTap: _handleSendMessage,
                              child: Container(
                                height: 48,
                                width: 48,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    )
                                  ],
                                ),
                                child: const Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 20,
                                ),
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
    );
  }

  Widget _buildQuickPrompt(String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () {
          _messageController.text = text;
          _handleSendMessage();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
