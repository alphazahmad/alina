import 'package:flutter/material.dart';
import '../services/namaz_service.dart';
import '../screens/namaz_history_sheet.dart';
import '../services/prayer_time_service.dart';

class HijriDate {
  static String getTodayHijri() {
    final date = DateTime.now();
    int y = date.year;
    int m = date.month;
    int d = date.day;

    if (m <= 2) {
      y -= 1;
      m += 12;
    }

    int A = (y / 100).floor();
    int B = (A / 4).floor();
    int C = 2 - A + B;
    int E = (365.25 * (y + 4716)).floor();
    int F = (30.6001 * (m + 1)).floor();
    double jd = C + d + E + F - 1524.5;

    int base = (jd - 1948439.5).round();
    int hYear = ((base * 30 + 10646) / 10631).floor();
    int daysInPriorYears = ((hYear - 1) * 354 + ((hYear - 1) * 11 + 3) / 30).floor();
    int dayOfYear = base - daysInPriorYears;

    int hMonth = 1;
    int hDay = 1;

    final monthLengths = [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29];
    bool isLeap = ((hYear * 11 + 14) % 30) < 11;

    int tempDays = dayOfYear;
    for (int i = 0; i < 12; i++) {
      int len = monthLengths[i];
      if (i == 11 && isLeap) len = 30;
      if (tempDays <= len) {
        hMonth = i + 1;
        hDay = tempDays;
        break;
      }
      tempDays -= len;
    }

    final hijriMonths = [
      'Muharram', 'Safar', 'Rabi\' al-Awwal', 'Rabi\' al-Thani',
      'Jumada al-Awwal', 'Jumada al-Thani', 'Rajab', 'Sha\'ban',
      'Ramadan', 'Shawwal', 'Dhu al-Qi\'dah', 'Dhu al-Hijjah'
    ];

    return '$hDay ${hijriMonths[hMonth - 1]} $hYear AH';
  }
}

class NamazDashboard extends StatefulWidget {
  final String uid;
  final bool isEmbedded;

  const NamazDashboard({
    super.key,
    required this.uid,
    this.isEmbedded = false,
  });

  @override
  State<NamazDashboard> createState() => _NamazDashboardState();
}

class _NamazDashboardState extends State<NamazDashboard> {
  final _namazService = NamazService();
  final _prayerTimeService = PrayerTimeService();
  
  Map<String, dynamic> _todayRecord = {};
  Map<String, DateTime> _todayPrayerTimes = {};
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
      final times = await _prayerTimeService.getPrayerTimesForDate(DateTime.now());
      if (mounted) {
        setState(() {
          _todayRecord = record;
          _todayPrayerTimes = times;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading today namaz: $e');
    }
  }

  String _prayerTimeStr(String prayerKey) {
    final dt = _todayPrayerTimes[prayerKey];
    if (dt == null) return '--:--';
    final hr = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hr:$min $period';
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
      padding: EdgeInsets.symmetric(horizontal: widget.isEmbedded ? 0.0 : 16.0, vertical: 8.0),
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
            const SizedBox(height: 2),
            Text(
              _prayerTimeStr(key),
              style: TextStyle(
                fontSize: 8.5,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
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
