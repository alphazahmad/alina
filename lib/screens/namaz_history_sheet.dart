import 'package:flutter/material.dart';
import '../services/namaz_service.dart';
import '../services/prayer_time_service.dart';

class NamazHistorySheet extends StatefulWidget {
  final String uid;

  const NamazHistorySheet({
    super.key,
    required this.uid,
  });

  @override
  State<NamazHistorySheet> createState() => _NamazHistorySheetState();
}

class _NamazHistorySheetState extends State<NamazHistorySheet> {
  final _namazService = NamazService();
  final _prayerTimeService = PrayerTimeService();
  
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic> _dayRecord = {};
  Map<String, dynamic> _statsSummary = {};
  
  bool _isLoadingDay = true;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadDayRecord();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoadingStats = true;
    });
    try {
      final summary = await _namazService.getStatsSummary(widget.uid);
      if (mounted) {
        setState(() {
          _statsSummary = summary;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _loadDayRecord() async {
    setState(() {
      _isLoadingDay = true;
    });
    try {
      final record = await _namazService.getDayRecord(widget.uid, _selectedDate);
      if (mounted) {
        setState(() {
          _dayRecord = record;
          _isLoadingDay = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading day record: $e');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: NamazService.startDate,
      lastDate: DateTime.now(),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadDayRecord();
    }
  }

  Future<void> _updatePrayerStatus(String prayerKey, String newStatus) async {
    setState(() {
      _dayRecord[prayerKey] = newStatus;
    });
    
    await _namazService.saveDayRecord(widget.uid, _selectedDate, _dayRecord);
    _loadStats(); // Reload stats to show updated lifetime summary
  }

  String _getFormattedDateLabel(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final totalAttended = _statsSummary['totalAttended'] ?? 0;
    final totalQaza = _statsSummary['totalQaza'] ?? 0;
    final totalNotAttended = _statsSummary['totalNotAttended'] ?? 1;
    final streakDays = _statsSummary['streakDays'] ?? 0;
    
    final totalPrayers = totalAttended + totalQaza + totalNotAttended;
    final double attendanceRatio = totalPrayers > 0
        ? (totalAttended / totalPrayers)
        : 0.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1016) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          const SizedBox(height: 12),
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
          const SizedBox(height: 16),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Namaz Tracker',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Lifetime Stats Cards
                  _isLoadingStats
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Lifetime Analytics',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$streakDays Day Streak',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Stats Grid
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricCard(
                                    title: 'Attended',
                                    count: totalAttended,
                                    color: Colors.green,
                                    icon: Icons.check_circle_outline,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMetricCard(
                                    title: 'Qaza',
                                    count: totalQaza,
                                    color: Colors.orange,
                                    icon: Icons.access_time,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMetricCard(
                                    title: 'Missed',
                                    count: totalNotAttended,
                                    color: Colors.red,
                                    icon: Icons.cancel_outlined,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Attendance bar
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C1A23) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'On-Time Attendance Performance',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        '${(attendanceRatio * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: attendanceRatio,
                                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                      minHeight: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  
                  const SizedBox(height: 24),
                  
                  // Location Settings Dropdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Prayer Calculation City',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C1A23) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: _prayerTimeService.currentCity.name,
                          underline: const SizedBox(),
                          dropdownColor: isDark ? const Color(0xFF1E1016) : Colors.white,
                          onChanged: (newCity) {
                            if (newCity != null) {
                              setState(() {
                                _prayerTimeService.setCity(newCity);
                              });
                              _loadDayRecord(); // Recalculate if today is selected
                            }
                          },
                          items: PrayerTimeService.cities.map((city) {
                            return DropdownMenuItem<String>(
                              value: city.name,
                              child: Text(city.name, style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  
                  // Date Picker Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tracking Record Date',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getFormattedDateLabel(_selectedDate),
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: const Text('Change Date', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Prayers list logger
                  _isLoadingDay
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 5,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
                            final key = prayers[index].toLowerCase();
                            final status = _dayRecord[key] ?? 'Upcoming';
                            
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C1A23) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ],
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        prayers[index],
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      _buildStatusBadge(status),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Quick Status selectors
                                  Row(
                                    children: [
                                      _buildSelectorButton(key, 'Attended', Colors.green, status),
                                      const SizedBox(width: 8),
                                      _buildSelectorButton(key, 'Qaza', Colors.orange, status),
                                      const SizedBox(width: 8),
                                      _buildSelectorButton(key, 'Not Attended', Colors.red, status),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C1A23) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    if (status == 'Attended') color = Colors.green;
    if (status == 'Qaza') color = Colors.orange;
    if (status == 'Not Attended') color = Colors.red;
    if (status == 'Upcoming') color = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSelectorButton(String prayerKey, String targetStatus, Color color, String currentStatus) {
    final isSelected = currentStatus == targetStatus;
    
    return Expanded(
      child: OutlinedButton(
        onPressed: () => _updatePrayerStatus(prayerKey, targetStatus),
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          side: BorderSide(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 1.8 : 1.0,
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          targetStatus == 'Not Attended' ? 'Missed' : targetStatus,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? color : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
