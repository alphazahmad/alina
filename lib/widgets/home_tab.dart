import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/auth_service.dart';
import '../services/routine_service.dart';
import '../widgets/routine_dashboard.dart';

class HomeTab extends StatefulWidget {
  final String uid;
  final int relationshipLevel;
  final int lovePoints;
  final String alinaMood;
  final Map<String, Map<String, dynamic>> last7DaysRecords;
  final bool isLoading;
  final VoidCallback onRefresh;

  const HomeTab({
    super.key,
    required this.uid,
    required this.relationshipLevel,
    required this.lovePoints,
    required this.alinaMood,
    required this.last7DaysRecords,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _routineService = RoutineService();
  List<RoutineTask> _todayRoutineTasks = [];
  bool _routineLoading = true;

  // Quick stats
  int _todayNamazAttended = 0;
  String _financeBalance = '—';

  @override
  void initState() {
    super.initState();
    _loadQuickStats();
    _loadTodayRoutine();
  }

  Future<void> _loadQuickStats() async {
    // Count today's attended namaaz from last7days records
    final todayKey = _formatDate(DateTime.now());
    final todayRecord = widget.last7DaysRecords[todayKey];
    if (todayRecord != null) {
      int count = 0;
      for (final p in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
        if (todayRecord[p] == 'Attended') count++;
      }
      if (mounted) setState(() => _todayNamazAttended = count);
    }

    // Load finance balance snapshot
    try {
      final isSandbox = AuthService().isSandboxMode;
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      if (!isSandbox) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('finance_months')
            .doc(monthKey)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          final balance = (data['totalIncome'] ?? 0.0) - (data['totalExpenses'] ?? 0.0);
          if (mounted) setState(() => _financeBalance = 'Rs ${balance.toStringAsFixed(0)}');
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/finance_$monthKey.json');
        if (await file.exists()) {
          final raw = jsonDecode(await file.readAsString());
          final balance = (raw['totalIncome'] ?? 0.0) - (raw['totalExpenses'] ?? 0.0);
          if (mounted) setState(() => _financeBalance = 'Rs ${balance.toStringAsFixed(0)}');
        }
      }
    } catch (_) {}
  }

  Future<void> _loadTodayRoutine() async {
    try {
      final tasks = await _routineService.getUnifiedTimetable(widget.uid, DateTime.now());
      if (mounted) {
        setState(() {
          _todayRoutineTasks = tasks.take(3).toList();
          _routineLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _routineLoading = false);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  void didUpdateWidget(HomeTab old) {
    super.didUpdateWidget(old);
    if (old.last7DaysRecords != widget.last7DaysRecords) {
      _loadQuickStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ─── Alina Hero Card ───────────────────────────────────────
        _buildAlinaHeroCard(theme, isDark),
        const SizedBox(height: 20),

        // ─── Quick Stats ───────────────────────────────────────────
        _buildSectionLabel('Quick Overview', theme),
        const SizedBox(height: 10),
        _buildQuickStatsRow(theme, isDark),
        const SizedBox(height: 20),

        // ─── Today's Schedule Preview ──────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionLabel("Today's Schedule", theme),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: Text('Weekly Routine', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                      centerTitle: true,
                    ),
                    body: RoutineDashboard(uid: widget.uid),
                  ),
                ),
              ),
              child: Text('See All', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildSchedulePreview(theme, isDark),
        const SizedBox(height: 20),

        // ─── Last 7 Days Progress ──────────────────────────────────
        _buildSectionLabel('Last 7 Days • Namaz', theme),
        const SizedBox(height: 10),
        _buildWeeklyProgressRow(theme, isDark),
      ],
    );
  }

  Widget _buildSectionLabel(String text, ThemeData theme) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.primary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildAlinaHeroCard(ThemeData theme, bool isDark) {
    final lvl = widget.relationshipLevel;
    final pts = widget.lovePoints;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF25101A), const Color(0xFF121212)]
              : [const Color(0xFFFFF5F8), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.primary, width: 2.5),
                  image: const DecorationImage(
                    image: AssetImage('assets/alina.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                  border: Border.all(color: isDark ? const Color(0xFF1E0414) : Colors.white, width: 2),
                ),
                child: const Icon(Icons.favorite, color: Colors.white, size: 11),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Alina',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1A0010),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Lvl $lvl',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  widget.alinaMood,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                // Love points bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (pts % 100) / 100,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$pts pts',
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsRow(ThemeData theme, bool isDark) {
    final stats = [
      {'icon': Icons.mosque_outlined, 'label': 'Today Namaz', 'value': '$_todayNamazAttended / 5', 'color': const Color(0xFF009688)},
      {'icon': Icons.account_balance_wallet_outlined, 'label': 'This Month', 'value': _financeBalance, 'color': const Color(0xFF4CAF50)},
      {'icon': Icons.radio_button_checked, 'label': 'Zikr', 'value': 'Today', 'color': theme.colorScheme.primary},
    ];

    return Row(
      children: stats.map((s) {
        final color = s['color'] as Color;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121212) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(s['icon'] as IconData, color: color, size: 20),
                const SizedBox(height: 6),
                Text(
                  s['value'] as String,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(s['label'] as String, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSchedulePreview(ThemeData theme, bool isDark) {
    if (_routineLoading) {
      return const Center(child: SizedBox(height: 48, child: CircularProgressIndicator()));
    }
    if (_todayRoutineTasks.isEmpty) {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text('Weekly Routine', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)), centerTitle: true),
              body: RoutineDashboard(uid: widget.uid),
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121212) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              Icon(Icons.schedule, color: Colors.grey.shade400, size: 32),
              const SizedBox(height: 8),
              Text('No tasks scheduled today', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              const SizedBox(height: 4),
              Text('Tap to open Routine Planner →', style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _todayRoutineTasks.map((task) {
        final color = Color(int.parse(task.colorHex.replaceFirst('#', '0xFF')));
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121212) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 12),
              Text(task.startTime, style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(task.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
              ),
              if (task.isCompleted)
                Icon(Icons.check_circle, color: Colors.green, size: 16)
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(task.category, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeeklyProgressRow(ThemeData theme, bool isDark) {
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));

    return Row(
      children: List.generate(7, (i) {
        final day = monday.add(Duration(days: i));
        final key = _formatDate(day);
        final record = widget.last7DaysRecords[key];
        final isToday = day.day == now.day && day.month == now.month && day.year == now.year;

        int attended = 0;
        if (record != null) {
          for (final p in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
            if (record[p] == 'Attended') attended++;
          }
        }

        Color barColor = Colors.grey.shade300;
        if (attended >= 5) {
          barColor = Colors.green;
        } else if (attended >= 3) {
          barColor = Colors.orange;
        } else if (attended >= 1) {
          barColor = Colors.red.shade300;
        }

        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              children: [
                Text(dayLabels[i], style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
                const SizedBox(height: 4),
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: record == null ? (isDark ? const Color(0xFF121212) : Colors.grey.shade100) : barColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: isToday ? Border.all(color: theme.colorScheme.primary, width: 1.5) : null,
                  ),
                  child: Center(
                    child: Text(
                      record == null ? '·' : '$attended',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: record == null ? Colors.grey.shade400 : barColor),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text('/5', style: const TextStyle(fontSize: 8, color: Colors.grey)),
              ],
            ),
          ),
        );
      }),
    );
  }
}
