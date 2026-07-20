import 'package:flutter/material.dart';
import '../services/routine_service.dart';
import '../screens/add_routine_sheet.dart';

class RoutineDashboard extends StatefulWidget {
  final String uid;

  const RoutineDashboard({
    super.key,
    required this.uid,
  });

  @override
  State<RoutineDashboard> createState() => _RoutineDashboardState();
}

class _RoutineDashboardState extends State<RoutineDashboard> {
  final _routineService = RoutineService();

  DateTime _selectedDate = DateTime.now();
  String _selectedCity = 'Nagpur';
  String _activeFilter = 'All';

  List<RoutineTask> _timetableTasks = [];
  bool _isLoading = true;

  final List<String> _filterOptions = ['All', 'Work', 'Personal', 'Spiritual', 'Health', 'High Priority'];

  @override
  void initState() {
    super.initState();
    _loadTimetableData();
  }

  Future<void> _loadTimetableData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final tasks = await _routineService.getUnifiedTimetable(widget.uid, _selectedDate, city: _selectedCity);
      if (mounted) {
        setState(() {
          _timetableTasks = tasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading timetable data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openAddSheet([RoutineTask? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddRoutineSheet(
        uid: widget.uid,
        existingTask: existing,
        onSaved: _loadTimetableData,
      ),
    );
  }

  Future<void> _toggleTask(RoutineTask task) async {
    if (task.source != 'user') return;
    await _routineService.toggleTaskCompleted(widget.uid, task);
    _loadTimetableData();
  }

  Future<void> _deleteTask(String id) async {
    await _routineService.deleteTask(widget.uid, id);
    _loadTimetableData();
  }

  double _calculateCompletionPercentage() {
    if (_timetableTasks.isEmpty) return 0.0;
    final completedCount = _timetableTasks.where((t) => t.isCompleted).length;
    return completedCount / _timetableTasks.length;
  }

  List<RoutineTask> _getFilteredTasks() {
    if (_activeFilter == 'All') return _timetableTasks;
    if (_activeFilter == 'High Priority') {
      return _timetableTasks.where((t) => t.priority == 'High').toList();
    }
    return _timetableTasks.where((t) => t.category == _activeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredTasks = _getFilteredTasks();
    final completionRatio = _calculateCompletionPercentage();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Productivity Summary & City Header
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // City & Productivity Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily Productivity',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  '${(completionRatio * 100).toStringAsFixed(0)}% Schedule Completed',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedCity,
                                underline: const SizedBox(),
                                dropdownColor: isDark ? const Color(0xFF121212) : Colors.white,
                                icon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
                                onChanged: (newCity) {
                                  if (newCity != null) {
                                    setState(() {
                                      _selectedCity = newCity;
                                    });
                                    _loadTimetableData();
                                  }
                                },
                                items: ['Nagpur', 'Islamabad', 'Karachi', 'Lahore', 'Dhaka', 'Dubai', 'London', 'New York'].map((c) {
                                  return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)));
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: completionRatio,
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 7-Day Weekday Selector Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (index) {
                      final now = DateTime.now();
                      // Start of current week (Monday)
                      final monday = now.subtract(Duration(days: now.weekday - 1));
                      final dayDate = monday.add(Duration(days: index));

                      final isSelected = dayDate.year == _selectedDate.year &&
                          dayDate.month == _selectedDate.month &&
                          dayDate.day == _selectedDate.day;

                      final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate = dayDate;
                          });
                          _loadTimetableData();
                        },
                        child: Container(
                          width: 42,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : (isDark ? const Color(0xFF121212) : Colors.white),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: isSelected
                                ? [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                dayLabels[index],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white70 : Colors.grey,
                                ),
                              ),
                              Text(
                                '${dayDate.day}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),

                // Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: _filterOptions.map((filter) {
                      final isSelected = _activeFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          selectedColor: theme.colorScheme.primary,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.05),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : theme.colorScheme.primary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _activeFilter = filter;
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Timetable Schedule Feed
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12.0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black : Colors.white.withValues(alpha: 0.6),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32.0),
                      ),
                    ),
                    child: filteredTasks.isEmpty
                        ? const Center(
                            child: Text(
                              'No routine tasks scheduled for this day.\nTap + below to add a new task.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredTasks.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            padding: const EdgeInsets.only(bottom: 80),
                            itemBuilder: (context, index) {
                              final task = filteredTasks[index];
                              return _buildTaskCard(task, theme, isDark);
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTaskCard(RoutineTask task, ThemeData theme, bool isDark) {
    final color = Color(int.parse(task.colorHex.replaceFirst('#', '0xFF')));
    final isAuto = task.source != 'user';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: task.isCompleted ? Colors.grey.withValues(alpha: 0.2) : color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Time Slot Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  task.startTime,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
                ),
                Text(
                  task.endTime,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          color: task.isCompleted ? Colors.grey : null,
                        ),
                      ),
                    ),
                    if (task.priority == 'High')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Text('HIGH', style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${task.category}${isAuto ? " • Auto Integrated" : ""}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Completion Checkbox or Auto Icon
          if (!isAuto)
            Checkbox(
              value: task.isCompleted,
              activeColor: color,
              onChanged: (_) => _toggleTask(task),
            )
          else
            Icon(
              task.source == 'namaz' ? Icons.mosque : Icons.event,
              color: color,
              size: 20,
            ),

          if (!isAuto)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
              onPressed: () => _deleteTask(task.id),
            ),
        ],
      ),
    );
  }
}
