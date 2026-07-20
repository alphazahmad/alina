import 'package:flutter/material.dart';
import '../services/calendar_service.dart';
import '../services/namaz_service.dart';
import '../services/finance_service.dart';
import '../screens/add_event_sheet.dart';

class CalendarDashboard extends StatefulWidget {
  final String uid;

  const CalendarDashboard({
    super.key,
    required this.uid,
  });

  @override
  State<CalendarDashboard> createState() => _CalendarDashboardState();
}

class _CalendarDashboardState extends State<CalendarDashboard> {
  final _calendarService = CalendarService();
  final _namazService = NamazService();
  final _financeService = FinanceService();

  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  int _currentViewIndex = 0; // 0: Month View, 1: Year View, 2: Agenda View
  String _searchQuery = '';
  final _searchController = TextEditingController();

  List<CalendarEvent> _allGeneratedEvents = [];
  Map<String, dynamic>? _selectedDayNamazRecord;
  List<FinanceTransaction> _selectedDayTransactions = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCalendarData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCalendarData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final userEvents = await _calendarService.getUserEvents(widget.uid);
      final nationalHolidays = _calendarService.getNationalHolidays(_focusedMonth.year);
      final islamicEvents = _calendarService.getIslamicEvents(_focusedMonth.year);

      // Load cross-module Namaz & Finance records for the selected date
      final namazRecord = await _namazService.getDayRecord(widget.uid, _selectedDate);
      final selectedDateStr = _formatDate(_selectedDate);
      final monthKey = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}';
      final monthTrans = await _financeService.getTransactions(widget.uid, monthKey);
      final dayTrans = monthTrans.where((t) => t.date == selectedDateStr).toList();

      if (mounted) {
        setState(() {
          _allGeneratedEvents = [...userEvents, ...nationalHolidays, ...islamicEvents];
          _selectedDayNamazRecord = namazRecord;
          _selectedDayTransactions = dayTrans;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading calendar data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectMonthYearDirect(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    int selectedYear = _focusedMonth.year;
    int selectedMonth = _focusedMonth.month;

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
      setState(() {
        _focusedMonth = picked;
        _selectedDate = DateTime(picked.year, picked.month, 1);
      });
      _loadCalendarData();
    }
  }

  void _openAddSheet([CalendarEvent? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEventSheet(
        uid: widget.uid,
        initialDate: _selectedDate,
        existingEvent: existing,
        onSaved: _loadCalendarData,
      ),
    );
  }

  Future<void> _toggleEvent(CalendarEvent e) async {
    if (e.type == 'holiday' || e.type == 'islamic') return;
    await _calendarService.toggleEventCompleted(widget.uid, e);
    _loadCalendarData();
  }

  Future<void> _deleteEvent(String id) async {
    await _calendarService.deleteEvent(widget.uid, id);
    _loadCalendarData();
  }

  List<CalendarEvent> _getEventsForDate(DateTime date) {
    final dateStr = _formatDate(date);
    return _allGeneratedEvents.where((e) {
      if (e.repeatType == 'yearly') {
        final p = e.date.split('-');
        return p.length == 3 && int.parse(p[1]) == date.month && int.parse(p[2]) == date.day;
      }
      return e.date == dateStr;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Search & View Selector Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF121212) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        // Search Input
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search events or categories...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.primary.withValues(alpha: 0.05),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim().toLowerCase();
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // View Segment Switcher
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(
                              value: 0,
                              label: Text('Month View', style: TextStyle(fontSize: 11)),
                              icon: Icon(Icons.calendar_view_month, size: 14),
                            ),
                            ButtonSegment(
                              value: 1,
                              label: Text('Year View', style: TextStyle(fontSize: 11)),
                              icon: Icon(Icons.calendar_month, size: 14),
                            ),
                            ButtonSegment(
                              value: 2,
                              label: Text('Agenda', style: TextStyle(fontSize: 11)),
                              icon: Icon(Icons.view_agenda, size: 14),
                            ),
                          ],
                          selected: {_currentViewIndex},
                          onSelectionChanged: (set) {
                            setState(() {
                              _currentViewIndex = set.first;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Main Calendar View Area
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8.0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black : Colors.white.withValues(alpha: 0.6),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32.0),
                      ),
                    ),
                    child: _buildBodyContent(theme, isDark),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task),
        label: const Text('Add Event', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBodyContent(ThemeData theme, bool isDark) {
    if (_searchQuery.isNotEmpty) {
      return _buildSearchResultsList(theme, isDark);
    }

    if (_currentViewIndex == 1) {
      return _buildYearViewGrid(theme, isDark);
    } else if (_currentViewIndex == 2) {
      return _buildAgendaView(theme, isDark);
    }

    return _buildMonthViewGrid(theme, isDark);
  }

  Widget _buildMonthViewGrid(ThemeData theme, bool isDark) {
    final monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final monthLabel = '${monthNames[_focusedMonth.month - 1]} ${_focusedMonth.year}';
    final hijri = _calendarService.getHijriDetails(_focusedMonth);

    // Days in Month math
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday; // 1: Mon, 7: Sun

    return Column(
      children: [
        // Month Navigation Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                });
                _loadCalendarData();
              },
            ),
            GestureDetector(
              onTap: () => _selectMonthYearDirect(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          monthLabel,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.primary),
                      ],
                    ),
                    Text(
                      '${hijri['monthName']} ${hijri['year']} AH',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                });
                _loadCalendarData();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Weekday Column Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
            return SizedBox(
              width: 36,
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // Calendar Grid
        Expanded(
          child: GridView.builder(
            itemCount: 42, // 6 rows of 7 days
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (context, index) {
              final dayOffset = index - (startingWeekday - 1);
              if (dayOffset < 0 || dayOffset >= daysInMonth) {
                return const SizedBox();
              }

              final dayNum = dayOffset + 1;
              final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
              final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;
              final isSelected = date.year == _selectedDate.year && date.month == _selectedDate.month && date.day == _selectedDate.day;

              final eventsOnDay = _getEventsForDate(date);
              final hijriDay = _calendarService.getHijriDetails(date)['day'];

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                  });
                  _loadCalendarData();
                },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : (isToday ? theme.colorScheme.primary.withValues(alpha: 0.15) : (isDark ? const Color(0xFF121212) : Colors.white)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isToday ? theme.colorScheme.primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      Text(
                        '$hijriDay',
                        style: TextStyle(
                          fontSize: 9,
                          color: isSelected ? Colors.white70 : Colors.grey,
                        ),
                      ),
                      if (eventsOnDay.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: eventsOnDay.take(3).map((e) {
                              final c = Color(int.parse(e.colorHex.replaceFirst('#', '0xFF')));
                              return Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? Colors.white : c,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom Selected Day Agenda Quick Preview
        const Divider(height: 16),
        Expanded(
          child: _buildAgendaView(theme, isDark),
        ),
      ],
    );
  }

  Widget _buildYearViewGrid(ThemeData theme, bool isDark) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Yearly Overview ${_focusedMonth.year}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
          ),
        ),
        Expanded(
          child: GridView.builder(
            itemCount: 12,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final monthNum = index + 1;
              final isCurrentMonth = _focusedMonth.month == monthNum;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, monthNum, 1);
                    _currentViewIndex = 0; // Switch to Month View
                  });
                  _loadCalendarData();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isCurrentMonth ? theme.colorScheme.primary : (isDark ? const Color(0xFF121212) : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        months[index],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCurrentMonth ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to View',
                        style: TextStyle(
                          fontSize: 10,
                          color: isCurrentMonth ? Colors.white70 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAgendaView(ThemeData theme, bool isDark) {
    final events = _getEventsForDate(_selectedDate);
    final hijri = _calendarService.getHijriDetails(_selectedDate);
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dateHeader = '${weekdays[_selectedDate.weekday - 1]}, ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year} • ${hijri['formatted']}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected Date Header
        Text(
          dateHeader,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              // Cross-Module Namaz Status Card for Selected Date
              if (_selectedDayNamazRecord != null) _buildNamazSummaryTile(theme, isDark),

              // Cross-Module Finance Transactions for Selected Date
              if (_selectedDayTransactions.isNotEmpty) ..._selectedDayTransactions.map((t) => _buildFinanceTile(t, theme, isDark)),

              // Events for Selected Date
              if (events.isEmpty && _selectedDayNamazRecord == null && _selectedDayTransactions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text('No events scheduled for this day.\nTap + below to add a reminder or event.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                )
              else
                ...events.map((e) => _buildEventCard(e, theme, isDark)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNamazSummaryTile(ThemeData theme, bool isDark) {
    final r = _selectedDayNamazRecord!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.mosque, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily Prayers Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  'Fajr: ${r['fajr'] ?? 'Upcoming'} • Dhuhr: ${r['dhuhr'] ?? 'Upcoming'} • Asr: ${r['asr'] ?? 'Upcoming'}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceTile(FinanceTransaction t, ThemeData theme, bool isDark) {
    final isIncome = t.type == 'income';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isIncome ? Colors.green : Colors.red).withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: isIncome ? Colors.green : Colors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.note.isEmpty ? t.category : t.note, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('${t.category} • Finance Entry', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text(
            '${isIncome ? "+" : "-"}${t.amount.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isIncome ? Colors.green : Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(CalendarEvent e, ThemeData theme, bool isDark) {
    final color = Color(int.parse(e.colorHex.replaceFirst('#', '0xFF')));
    final isStatic = e.type == 'holiday' || e.type == 'islamic';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (!isStatic)
            Checkbox(
              value: e.isCompleted,
              activeColor: color,
              onChanged: (_) => _toggleEvent(e),
            )
          else
            Icon(Icons.stars, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    decoration: e.isCompleted ? TextDecoration.lineThrough : null,
                    color: e.isCompleted ? Colors.grey : null,
                  ),
                ),
                Text(
                  '${e.time} • ${e.category}${e.description.isNotEmpty ? " • ${e.description}" : ""}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (e.priority == 'High')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Text('HIGH', style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          if (!isStatic)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
              onPressed: () => _deleteEvent(e.id),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsList(ThemeData theme, bool isDark) {
    final matched = _allGeneratedEvents.where((e) {
      return e.title.toLowerCase().contains(_searchQuery) ||
          e.category.toLowerCase().contains(_searchQuery) ||
          e.description.toLowerCase().contains(_searchQuery);
    }).toList();

    if (matched.isEmpty) {
      return const Center(child: Text('No events found matching your search query.'));
    }

    return ListView.builder(
      itemCount: matched.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        return _buildEventCard(matched[index], theme, isDark);
      },
    );
  }
}
