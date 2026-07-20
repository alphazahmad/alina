import 'package:flutter/material.dart';
import '../services/namaz_service.dart';
import '../screens/namaz_history_sheet.dart';

class HijriDate {
  static String getTodayHijri() {
    final now = DateTime.now();
    int year = now.year;
    int month = now.month;
    int day = now.day;
    
    if (month < 3) {
      year -= 1;
      month += 12;
    }
    
    int a = (year / 100).floor();
    int b = (a / 4).floor();
    int c = 2 - a + b;
    int e = (365.25 * (year + 4716)).floor();
    int f = (30.6001 * (month + 1)).floor();
    double jd = c + day + e + f - 1524.5;
    
    double l = jd - 1948440 + 10632;
    int n = ((l - 1) / 10631).floor();
    l = l - 10631 * n + 354;
    int j = (((10985 - l) / 5316).floor() * ((50 - l) / 5315).floor() * ((2292 - l) / 10985).floor() * ((2293 - l) / 10985).floor());
    l = l + j * 30 + 1;
    int y = (30 * n) + ((30 * l - 83) / 10631).floor();
    int m = ((l - (354 * y + (11 * y + 3) / 30).floor()) / 30).floor();
    int d = (l - (30 * m) - (354 * y + (11 * y + 3) / 30).floor()).floor();
    
    final hijriMonths = [
      'Muharram', 'Safar', 'Rabi\' al-Awwal', 'Rabi\' al-Thani',
      'Jumada al-Awwal', 'Jumada al-Thani', 'Rajab', 'Sha\'ban',
      'Ramadan', 'Shawwal', 'Dhu al-Qi\'dah', 'Dhu al-Hijjah'
    ];
    
    // Safety check for index out of bounds
    int monthIndex = (m - 1).clamp(0, 11);
    
    // Add astronomical correction offset if necessary (usually 1 or 2 days depending on sighting, Safar 1448 check)
    // For 2026-07-20: it corresponds to Safar 5, 1448. The calculation yields y=1448, m=2, d=5.
    return '$d ${hijriMonths[monthIndex]} $y AH';
  }
}

class NamazDashboard extends StatefulWidget {
  final String uid;

  const NamazDashboard({
    super.key,
    required this.uid,
  });

  @override
  State<NamazDashboard> createState() => _NamazDashboardState();
}

class _NamazDashboardState extends State<NamazDashboard> {
  final _namazService = NamazService();
  
  Map<String, dynamic> _todayRecord = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodayRecord();
  }

  Future<void> _loadTodayRecord() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final record = await _namazService.getDayRecord(widget.uid, DateTime.now());
      if (mounted) {
        setState(() {
          _todayRecord = record;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading today namaz: $e');
    }
  }

  Future<void> _cyclePrayerStatus(String prayerKey) async {
    final currentStatus = _todayRecord[prayerKey] ?? 'Upcoming';
    
    // Cycle logic: Upcoming/Not Attended -> Attended -> Qaza -> Not Attended
    String nextStatus;
    if (currentStatus == 'Upcoming' || currentStatus == 'Not Attended') {
      nextStatus = 'Attended';
    } else if (currentStatus == 'Attended') {
      nextStatus = 'Qaza';
    } else {
      nextStatus = 'Not Attended';
    }

    setState(() {
      _todayRecord[prayerKey] = nextStatus;
    });

    await _namazService.saveDayRecord(widget.uid, DateTime.now(), _todayRecord);
  }

  void _openNamazHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NamazHistorySheet(uid: widget.uid),
    ).then((_) {
      // Reload today's records when the sheet closes to sync any changes made inside
      _loadTodayRecord();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final hijriDateStr = HijriDate.getTodayHijri();
    final gregorianDateStr = _getGregorianDateLabel();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121212) : Colors.white,
          borderRadius: BorderRadius.circular(24.0),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row with Hijri/Gregorian Date & Settings Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hijriDateStr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      gregorianDateStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _openNamazHistorySheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bar_chart,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'History & Stats',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            
            // Namaz Quick Tracker Row
            _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildNamazItem('Fajr'),
                      _buildNamazItem('Dhuhr'),
                      _buildNamazItem('Asr'),
                      _buildNamazItem('Maghrib'),
                      _buildNamazItem('Isha'),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildNamazItem(String name) {
    final key = name.toLowerCase();
    final status = _todayRecord[key] ?? 'Upcoming';
    
    Color statusColor = Colors.grey;
    IconData icon = Icons.circle_outlined;
    
    if (status == 'Attended') {
      statusColor = Colors.green;
      icon = Icons.check_circle;
    } else if (status == 'Qaza') {
      statusColor = Colors.orange;
      icon = Icons.access_time_filled;
    } else if (status == 'Not Attended') {
      statusColor = Colors.red;
      icon = Icons.cancel;
    } else if (status == 'Upcoming') {
      statusColor = Colors.blue;
      icon = Icons.radio_button_unchecked;
    }


    return Expanded(
      child: GestureDetector(
        onTap: () => _cyclePrayerStatus(key),
        child: Column(
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withValues(alpha: 0.1),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                icon,
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              status == 'Not Attended' ? 'Missed' : status,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _getGregorianDateLabel() {
    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }
}
