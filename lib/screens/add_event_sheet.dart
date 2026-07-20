import 'package:flutter/material.dart';
import '../services/calendar_service.dart';

class AddEventSheet extends StatefulWidget {
  final String uid;
  final DateTime? initialDate;
  final CalendarEvent? existingEvent;
  final VoidCallback onSaved;

  const AddEventSheet({
    super.key,
    required this.uid,
    this.initialDate,
    this.existingEvent,
    required this.onSaved,
  });

  @override
  State<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<AddEventSheet> {
  final _calendarService = CalendarService();

  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  late DateTime _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

  String _eventType = 'temporary'; // 'temporary' or 'recurring'
  String _category = 'Personal';
  String _priority = 'Medium';
  String _colorHex = '#F52670';
  String _repeatType = 'none';
  String _reminderTime = '15 mins before';

  final List<String> _colorHexes = [
    '#F52670', // Primary Pink
    '#FF9800', // Orange
    '#4CAF50', // Green
    '#2196F3', // Blue
    '#9C27B0', // Purple
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();

    if (widget.existingEvent != null) {
      final e = widget.existingEvent!;
      _titleController.text = e.title;
      _descController.text = e.description;
      _eventType = e.type;
      _category = e.category;
      _priority = e.priority;
      _colorHex = e.colorHex;
      _repeatType = e.repeatType;
      _reminderTime = e.reminderTime;

      try {
        _selectedDate = DateTime.parse(e.date);
        final timeParts = e.time.split(':');
        _selectedTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveEvent() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final timeStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    final newId = widget.existingEvent?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    final event = CalendarEvent(
      id: newId,
      title: title,
      description: _descController.text.trim(),
      date: dateStr,
      time: timeStr,
      type: _eventType,
      category: _category,
      priority: _priority,
      colorHex: _colorHex,
      isCompleted: widget.existingEvent?.isCompleted ?? false,
      repeatType: _eventType == 'recurring' ? 'yearly' : _repeatType,
      reminderTime: _reminderTime,
    );

    await _calendarService.addOrUpdateEvent(widget.uid, event);

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
                widget.existingEvent != null ? 'Edit Calendar Event' : 'Add Calendar Event',
                style: TextStyle(
                  fontSize: 20,
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
          const SizedBox(height: 12),

          // Event Type Segment
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'temporary',
                label: Text('Temporary Event', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.event, size: 14),
              ),
              ButtonSegment(
                value: 'recurring',
                label: Text('Yearly Birthday / Event', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.cake, size: 14),
              ),
            ],
            selected: {_eventType},
            onSelectionChanged: (set) {
              setState(() {
                _eventType = set.first;
              });
            },
          ),
          const Divider(height: 24),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Event Title (e.g. Birthday, Meeting)',
                      prefixIcon: Icon(Icons.title),
                      border: OutlineInputBorder(),
                    ),
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
                          items: CalendarService.categories.map((c) {
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
                          items: CalendarService.priorities.map((p) {
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

                  // Date & Time Row
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              prefixIcon: Icon(Icons.calendar_month),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: _pickTime,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Time',
                              prefixIcon: Icon(Icons.access_time),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              _selectedTime.format(context),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Reminder Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _reminderTime,
                    decoration: const InputDecoration(
                      labelText: 'Reminder Notice',
                      prefixIcon: Icon(Icons.notifications_active),
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: isDark ? const Color(0xFF121212) : Colors.white,
                    items: CalendarService.reminderOptions.map((r) {
                      return DropdownMenuItem(value: r, child: Text(r));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _reminderTime = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Color Picker Choice Chips
                  const Text('Color Label', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _colorHexes.map((hexStr) {
                      final color = Color(int.parse(hexStr.replaceFirst('#', '0xFF')));
                      final isSelected = _colorHex == hexStr;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _colorHex = hexStr;
                          });
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                            boxShadow: isSelected
                                ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)]
                                : null,
                          ),
                          child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Notes / Description
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Event Details / Notes (Optional)',
                      prefixIcon: Icon(Icons.notes),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          ElevatedButton(
            onPressed: _saveEvent,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Save Event', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
