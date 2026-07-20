import 'package:flutter/material.dart';
import '../services/routine_service.dart';

class AddRoutineSheet extends StatefulWidget {
  final String uid;
  final RoutineTask? existingTask;
  final VoidCallback onSaved;

  const AddRoutineSheet({
    super.key,
    required this.uid,
    this.existingTask,
    required this.onSaved,
  });

  @override
  State<AddRoutineSheet> createState() => _AddRoutineSheetState();
}

class _AddRoutineSheetState extends State<AddRoutineSheet> {
  final _routineService = RoutineService();
  final _titleController = TextEditingController();

  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 0);

  String _category = 'Personal';
  String _priority = 'Medium';
  String _repeatType = 'daily';
  List<int> _repeatDays = [1, 2, 3, 4, 5, 6, 7];
  String _colorHex = '#F52670';
  String _reminderNotice = 'At start time';

  final List<String> _colorHexes = [
    '#F52670', // Pink
    '#FF9800', // Orange
    '#4CAF50', // Green
    '#2196F3', // Blue
    '#9C27B0', // Purple
  ];

  final List<Map<String, dynamic>> _weekdays = [
    {'name': 'M', 'val': 1},
    {'name': 'T', 'val': 2},
    {'name': 'W', 'val': 3},
    {'name': 'T', 'val': 4},
    {'name': 'F', 'val': 5},
    {'name': 'S', 'val': 6},
    {'name': 'S', 'val': 7},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingTask != null) {
      final t = widget.existingTask!;
      _titleController.text = t.title;
      _category = t.category;
      _priority = t.priority;
      _repeatType = t.repeatType;
      _repeatDays = List<int>.from(t.repeatDays);
      _colorHex = t.colorHex;
      _reminderNotice = t.reminderNotice;

      try {
        final startP = t.startTime.split(':');
        _startTime = TimeOfDay(hour: int.parse(startP[0]), minute: int.parse(startP[1]));
        final endP = t.endTime.split(':');
        _endTime = TimeOfDay(hour: int.parse(endP[0]), minute: int.parse(endP[1]));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(context: context, initialTime: _endTime);
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final startStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
    final endStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';
    final newId = widget.existingTask?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    final task = RoutineTask(
      id: newId,
      title: title,
      startTime: startStr,
      endTime: endStr,
      category: _category,
      priority: _priority,
      repeatType: _repeatType,
      repeatDays: _repeatDays,
      isCompleted: widget.existingTask?.isCompleted ?? false,
      colorHex: _colorHex,
      reminderNotice: _reminderNotice,
      source: 'user',
    );

    await _routineService.addOrUpdateTask(widget.uid, task);

    if (mounted) {
      Navigator.of(context).pop();
    }
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.existingTask != null ? 'Edit Routine Task' : 'Add Routine Task',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Task Name (e.g. Exercise, Office, Reading)',
                      prefixIcon: Icon(Icons.schedule),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Start & End Time Row
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickStartTime,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start Time',
                              prefixIcon: Icon(Icons.access_time),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(_startTime.format(context), style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: _pickEndTime,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'End Time',
                              prefixIcon: Icon(Icons.access_time_filled),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(_endTime.format(context), style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Category & Priority Row
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(Icons.category),
                            border: OutlineInputBorder(),
                          ),
                          dropdownColor: isDark ? const Color(0xFF121212) : Colors.white,
                          items: RoutineService.categories.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _category = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _priority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                            prefixIcon: Icon(Icons.flag),
                            border: OutlineInputBorder(),
                          ),
                          dropdownColor: isDark ? const Color(0xFF121212) : Colors.white,
                          items: RoutineService.priorities.map((p) {
                            return DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _priority = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Recurrence Rules Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _repeatType,
                    decoration: const InputDecoration(
                      labelText: 'Recurrence Rule',
                      prefixIcon: Icon(Icons.repeat),
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: isDark ? const Color(0xFF121212) : Colors.white,
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('Everyday (Mon-Sun)')),
                      DropdownMenuItem(value: 'weekdays', child: Text('Weekdays Only (Mon-Fri)')),
                      DropdownMenuItem(value: 'weekends', child: Text('Weekends Only (Sat-Sun)')),
                      DropdownMenuItem(value: 'custom', child: Text('Custom Selected Days')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _repeatType = val;
                          if (val == 'daily') _repeatDays = [1, 2, 3, 4, 5, 6, 7];
                          if (val == 'weekdays') _repeatDays = [1, 2, 3, 4, 5];
                          if (val == 'weekends') _repeatDays = [6, 7];
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Custom Weekday ChoiceChips if 'custom' selected
                  if (_repeatType == 'custom') ...[
                    const Text('Select Days of Week', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _weekdays.map((item) {
                        final val = item['val'] as int;
                        final name = item['name'] as String;
                        final isSelected = _repeatDays.contains(val);

                        return FilterChip(
                          label: Text(name),
                          selected: isSelected,
                          selectedColor: theme.colorScheme.primary,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _repeatDays.add(val);
                              } else {
                                _repeatDays.remove(val);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Color Picker
                  const Text('Color Label', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _colorHexes.map((hexStr) {
                      final color = Color(int.parse(hexStr.replaceFirst('#', '0xFF')));
                      final isSelected = _colorHex == hexStr;

                      return GestureDetector(
                        onTap: () => setState(() => _colorHex = hexStr),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                            boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)] : null,
                          ),
                          child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          ElevatedButton(
            onPressed: _saveTask,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Save Routine Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
