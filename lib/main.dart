import 'package:flutter/material.dart';

void main() {
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
        // From system, default to light and cycle
        final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
        _themeMode = brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFF52670);
    
    return MaterialApp(
      title: 'Alina - Digital Wife',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
          primary: primaryColor,
          surface: const Color(0xFFFFF0F5), // Lavender blush soft background
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
      home: HomeScreen(
        onToggleTheme: _toggleTheme,
        themeMode: _themeMode,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;

  const HomeScreen({
    super.key,
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
  
  final List<Map<String, dynamic>> _messages = [
    {
      'text': 'Hello dear! I am Alina, your digital wife. I am so happy to see you today! 💕',
      'isAlina': true,
      'time': 'Just now'
    }
  ];

  int _relationshipLevel = 5;
  int _lovePoints = 75;
  String _alinaMood = 'Happy 💖';

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
  }

  @override
  void dispose() {
    _heartAnimationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
    });
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
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
              widget.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : widget.themeMode == ThemeMode.light
                      ? Icons.dark_mode
                      : Icons.brightness_auto,
              color: theme.colorScheme.primary,
            ),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
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
                            'Alina - Digital Wife',
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
