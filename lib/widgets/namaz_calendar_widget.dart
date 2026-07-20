import 'package:flutter/material.dart';
import '../services/namaz_service.dart';

/// A dedicated Namaz attendance calendar.
/// - Green day  = all 5 namaaz attended OR qaza (completed)
/// - Amber day  = 1–4 namaaz attended/qaza
/// - Red dot    = some missed
/// - Grey/empty = future or no record
class NamazCalendarWidget extends StatefulWidget {
  final String uid;

  const NamazCalendarWidget({super.key, required this.uid});

  @override
  State<NamazCalendarWidget> createState() => _NamazCalendarWidgetState();
}

class _NamazCalendarWidgetState extends State<NamazCalendarWidget> {
  final _namazService = NamazService();

  DateTime _displayMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  Map<String, Map<String, dynamic>> _monthRecords = {};
  bool _isLoadingMonth = true;
  bool _isLoadingStats = true;

  // Lifetime stats
  int _totalAttended = 0;
  int _totalQaza = 0;
  int _totalNotAttended = 0;
  int _streakDays = 0;

  @override
  void initState() {
    super.initState();
    _loadMonthData();
    _loadStats();
  }

  Future<void> _loadMonthData() async {
    if (!mounted) return;
    setState(() => _isLoadingMonth = true);

    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(_displayMonth.year, _displayMonth.month);
    final startDate = NamazService.startDate;

    final datesToFetch = <DateTime>[];
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(_displayMonth.year, _displayMonth.month, d);
      final today = DateTime(now.year, now.month, now.day);
      if (!date.isAfter(today) && !date.isBefore(startDate)) {
        datesToFetch.add(date);
      }
    }

    if (datesToFetch.isEmpty) {
      if (mounted) setState(() => _isLoadingMonth = false);
      return;
    }

    try {
      final records = await Future.wait(
        datesToFetch.map((d) => _namazService.getDayRecord(widget.uid, d)),
      );

      final Map<String, Map<String, dynamic>> monthMap = {};
      for (int i = 0; i < datesToFetch.length; i++) {
        monthMap[_namazService.formatDate(datesToFetch[i])] = records[i];
      }

      if (mounted) {
        setState(() {
          _monthRecords = monthMap;
          _isLoadingMonth = false;
        });
      }
    } catch (e) {
      debugPrint('NamazCalendar load error: $e');
      if (mounted) setState(() => _isLoadingMonth = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _namazService.getStatsSummary(widget.uid);
      if (mounted) {
        setState(() {
          _totalAttended = stats['totalAttended'] ?? 0;
          _totalQaza = stats['totalQaza'] ?? 0;
          _totalNotAttended = stats['totalNotAttended'] ?? 0;
          _streakDays = stats['streakDays'] ?? 0;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('NamazCalendar stats error: $e');
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  /// Returns how many prayers were "done" (Attended or Qaza) for a date key
  int _getDoneCount(String dateKey) {
    final record = _monthRecords[dateKey];
    if (record == null) return -1; // no record (future or before start)
    int done = 0;
    for (final p in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      final s = record[p] ?? '';
      if (s == 'Attended' || s == 'Qaza') done++;
    }
    return done;
  }

  Color _dayColor(int doneCount, ThemeData theme, bool isDark) {
    if (doneCount < 0) return Colors.transparent; // future/out of range
    if (doneCount == 5) return Colors.green;
    return Colors.transparent;
  }

  void _prevMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1, 1);
      _monthRecords = {};
    });
    _loadMonthData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 1);
    if (nextMonth.isAfter(DateTime(now.year, now.month, 1))) return;
    setState(() {
      _displayMonth = nextMonth;
      _monthRecords = {};
    });
    _loadMonthData();
  }

  Future<void> _selectMonthYearDirect(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    int selectedYear = _displayMonth.year;
    int selectedMonth = _displayMonth.month;

    final monthsList = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
              title: Text(
                'Select Month & Year',
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedYear,
                    dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
                    items: List.generate(21, (i) => 2015 + i).map((yr) {
                      return DropdownMenuItem(value: yr, child: Text('$yr'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedYear = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: selectedMonth,
                    dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder()),
                    items: List.generate(12, (i) => i + 1).map((mo) {
                      return DropdownMenuItem(value: mo, child: Text(monthsList[mo - 1]));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedMonth = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context, DateTime(selectedYear, selectedMonth, 1));
                  },
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null) {
      final now = DateTime.now();
      // Cap at current month
      final maxMonth = DateTime(now.year, now.month, 1);
      final finalDate = picked.isAfter(maxMonth) ? maxMonth : picked;
      
      setState(() {
        _displayMonth = finalDate;
        _monthRecords = {};
      });
      _loadMonthData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ─── Lifetime Stats Cards ──────────────────────────────────
        _buildSectionLabel('Salah stats', theme),
        const SizedBox(height: 10),
        _isLoadingStats
            ? const Center(child: SizedBox(height: 60, child: CircularProgressIndicator()))
            : _buildStatsGrid(theme, isDark),

        const SizedBox(height: 20),

        // ─── Streak Banner ─────────────────────────────────────────
        if (!_isLoadingStats)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_streakDays day streak', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const Text('Keep up the consistency!', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // ─── Month Navigation Header ───────────────────────────────
        _buildSectionLabel('Salah Attendance Calendar', theme),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _prevMonth,
              color: theme.colorScheme.primary,
            ),
            GestureDetector(
              onTap: () => _selectMonthYearDirect(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Text(
                      '${months[_displayMonth.month - 1]} ${_displayMonth.year}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _nextMonth,
              color: theme.colorScheme.primary,
            ),
          ],
        ),

        // ─── Day-of-week labels ────────────────────────────────────
        Row(
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) {
            return Expanded(
              child: Center(
                child: Text(d, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),

        // ─── Calendar Grid ─────────────────────────────────────────
        _isLoadingMonth
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            : _buildCalendarGrid(theme, isDark),

        const SizedBox(height: 16),

        // ─── Legend ────────────────────────────────────────────────
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _legendItem(Colors.green, 'All 5 Done', isDark),
            _legendItem(isDark ? Colors.grey.shade800 : Colors.grey.shade300, 'Incomplete / Idle', isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid(ThemeData theme, bool isDark) {
    final totalPossible = _totalAttended + _totalQaza + _totalNotAttended;
    final completionRate = totalPossible > 0 ? ((_totalAttended + _totalQaza) / totalPossible * 100) : 0.0;

    final stats = [
      {'label': 'On-Time Attended', 'value': '$_totalAttended', 'icon': Icons.check_circle, 'color': Colors.green},
      {'label': 'Qaza Offered', 'value': '$_totalQaza', 'icon': Icons.access_time_filled, 'color': Colors.orange},
      {'label': 'Remaining Qaza', 'value': '$_totalNotAttended', 'icon': Icons.cancel, 'color': Colors.red},
      {'label': 'Completion Rate', 'value': '${completionRate.toStringAsFixed(0)}%', 'icon': Icons.pie_chart, 'color': theme.colorScheme.primary},
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      children: stats.map((s) {
        final color = s['color'] as Color;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121212) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(s['icon'] as IconData, color: color, size: 22),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['value'] as String, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  Text(s['label'] as String, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid(ThemeData theme, bool isDark) {
    final firstDay = _displayMonth;
    final daysInMonth = DateUtils.getDaysInMonth(firstDay.year, firstDay.month);
    // weekday: Mon=1, Sun=7 → leading empty cells
    final startWeekday = firstDay.weekday; // 1=Mon

    final cells = <Widget>[];

    // Empty leading cells
    for (int i = 1; i < startWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(firstDay.year, firstDay.month, d);
      final dateKey = _namazService.formatDate(date);
      final isToday = date == today;
      final isFuture = date.isAfter(today);
      final isBeforeStart = date.isBefore(NamazService.startDate);

      final doneCount = (isFuture || isBeforeStart) ? -1 : _getDoneCount(dateKey);
      final bgColor = _dayColor(doneCount, theme, isDark);

      cells.add(
        Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: bgColor == Colors.transparent ? Colors.transparent : bgColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: isToday
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : (doneCount >= 0 ? Border.all(color: bgColor.withValues(alpha: 0.6), width: 1) : null),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$d',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                    color: isToday
                        ? theme.colorScheme.primary
                        : (isFuture || isBeforeStart)
                            ? Colors.grey.shade400
                            : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                if (doneCount >= 0 && doneCount < 5)
                  Text(
                    '$doneCount/5',
                    style: TextStyle(
                      fontSize: 8,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      children: cells,
    );
  }

  Widget _buildSectionLabel(String text, ThemeData theme) {
    return Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.colorScheme.primary, letterSpacing: 0.4),
    );
  }

  Widget _legendItem(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
