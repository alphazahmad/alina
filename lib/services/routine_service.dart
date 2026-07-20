import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'prayer_time_service.dart';
import 'calendar_service.dart';

class RoutineTask {
  final String id;
  final String title;
  final String startTime; // HH:mm
  final String endTime;   // HH:mm
  final String category;  // 'Personal', 'Work', 'Spiritual', 'Health', 'Other'
  final String priority;  // 'High', 'Medium', 'Low'
  final String repeatType;// 'daily', 'weekdays', 'weekends', 'weekly', 'custom'
  final List<int> repeatDays; // 1: Mon, 7: Sun
  final bool isCompleted;
  final String colorHex;
  final String reminderNotice;
  final String source; // 'user', 'namaz', 'calendar'

  RoutineTask({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.category = 'Personal',
    this.priority = 'Medium',
    this.repeatType = 'daily',
    this.repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    this.isCompleted = false,
    this.colorHex = '#F52670',
    this.reminderNotice = 'At start time',
    this.source = 'user',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startTime': startTime,
      'endTime': endTime,
      'category': category,
      'priority': priority,
      'repeatType': repeatType,
      'repeatDays': repeatDays,
      'isCompleted': isCompleted,
      'colorHex': colorHex,
      'reminderNotice': reminderNotice,
      'source': source,
    };
  }

  factory RoutineTask.fromMap(Map<String, dynamic> map) {
    return RoutineTask(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      startTime: map['startTime'] ?? '08:00',
      endTime: map['endTime'] ?? '09:00',
      category: map['category'] ?? 'Personal',
      priority: map['priority'] ?? 'Medium',
      repeatType: map['repeatType'] ?? 'daily',
      repeatDays: map['repeatDays'] != null ? List<int>.from(map['repeatDays']) : const [1, 2, 3, 4, 5, 6, 7],
      isCompleted: map['isCompleted'] ?? false,
      colorHex: map['colorHex'] ?? '#F52670',
      reminderNotice: map['reminderNotice'] ?? 'At start time',
      source: map['source'] ?? 'user',
    );
  }

  RoutineTask copyWith({
    String? id,
    String? title,
    String? startTime,
    String? endTime,
    String? category,
    String? priority,
    String? repeatType,
    List<int>? repeatDays,
    bool? isCompleted,
    String? colorHex,
    String? reminderNotice,
    String? source,
  }) {
    return RoutineTask(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      repeatType: repeatType ?? this.repeatType,
      repeatDays: repeatDays ?? this.repeatDays,
      isCompleted: isCompleted ?? this.isCompleted,
      colorHex: colorHex ?? this.colorHex,
      reminderNotice: reminderNotice ?? this.reminderNotice,
      source: source ?? this.source,
    );
  }
}

class RoutineService {
  static final RoutineService _instance = RoutineService._internal();
  factory RoutineService() => _instance;
  RoutineService._internal();

  final _prayerService = PrayerTimeService();
  final _calendarService = CalendarService();

  static const List<String> categories = ['Personal', 'Work', 'Spiritual', 'Health', 'Other'];
  static const List<String> priorities = ['High', 'Medium', 'Low'];
  static const List<String> repeatOptions = ['daily', 'weekdays', 'weekends', 'custom'];

  bool get _isFirebaseAvailable {
    try {
      return FirebaseFirestore.instance.app.name.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<File> _getLocalFile(String uid) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/routine_tasks_$uid.json');
  }

  // --- CRUD Handlers ---

  Future<List<RoutineTask>> getUserTasks(String uid) async {
    List<RoutineTask> localTasks = [];
    try {
      final file = await _getLocalFile(uid);
      if (await file.exists()) {
        final content = await file.readAsString();
        final List list = jsonDecode(content);
        localTasks = list.map((item) => RoutineTask.fromMap(item)).toList();
      }
    } catch (e) {
      debugPrint('Error loading sandbox routine tasks file: $e');
    }

    if (localTasks.isNotEmpty) {
      return localTasks;
    }

    if (_isFirebaseAvailable) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('routine_tasks')
            .get();

        final remoteTasks = snap.docs.map((doc) => RoutineTask.fromMap(doc.data())).toList();
        // Cache locally
        try {
          final file = await _getLocalFile(uid);
          await file.writeAsString(jsonEncode(remoteTasks.map((t) => t.toMap()).toList()));
        } catch (_) {}
        return remoteTasks;
      } catch (e) {
        debugPrint('Error loading routine tasks from Firestore: $e');
      }
    }

    return localTasks;
  }

  Future<void> addOrUpdateTask(String uid, RoutineTask task) async {
    if (_isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('routine_tasks')
            .doc(task.id)
            .set(task.toMap());
      } catch (e) {
        debugPrint('Error saving task to Firestore: $e');
      }
    }

    try {
      final tasks = await getUserTasks(uid);
      final index = tasks.indexWhere((t) => t.id == task.id);
      if (index >= 0) {
        tasks[index] = task;
      } else {
        tasks.add(task);
      }
      final file = await _getLocalFile(uid);
      await file.writeAsString(jsonEncode(tasks.map((t) => t.toMap()).toList()));
    } catch (e) {
      debugPrint('Error saving sandbox task: $e');
    }
  }

  Future<void> deleteTask(String uid, String taskId) async {
    if (_isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('routine_tasks')
            .doc(taskId)
            .delete();
      } catch (e) {
        debugPrint('Error deleting task from Firestore: $e');
      }
    }

    try {
      final tasks = await getUserTasks(uid);
      tasks.removeWhere((t) => t.id == taskId);
      final file = await _getLocalFile(uid);
      await file.writeAsString(jsonEncode(tasks.map((t) => t.toMap()).toList()));
    } catch (e) {
      debugPrint('Error updating sandbox tasks after delete: $e');
    }
  }

  Future<void> toggleTaskCompleted(String uid, RoutineTask task) async {
    final updated = task.copyWith(isCompleted: !task.isCompleted);
    await addOrUpdateTask(uid, updated);
  }

  // --- Recurrence & Unified Timetable Aggregator ---

  bool isTaskActiveOnDate(RoutineTask task, DateTime date) {
    final weekday = date.weekday; // 1: Mon, 7: Sun
    if (task.repeatType == 'daily') return true;
    if (task.repeatType == 'weekdays') return weekday <= 5;
    if (task.repeatType == 'weekends') return weekday >= 6;
    return task.repeatDays.contains(weekday);
  }

  Future<List<RoutineTask>> getUnifiedTimetable(String uid, DateTime date, {String city = 'Islamabad'}) async {
    final List<RoutineTask> unifiedList = [];

    // 1. Load User Routine Tasks active for date
    final userTasks = await getUserTasks(uid);
    for (final task in userTasks) {
      if (isTaskActiveOnDate(task, date)) {
        unifiedList.add(task);
      }
    }

    // 2. Auto-pull Namaz times calculated for current city
    try {
      _prayerService.setCity(city);
      final prayerTimes = _prayerService.getPrayerTimesForDate(date);
      for (final entry in prayerTimes.entries) {
        final pName = entry.key;
        final dt = entry.value;
        final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

        // End time is approx 20 mins after start
        final endDt = dt.add(const Duration(minutes: 20));
        final endTimeStr = '${endDt.hour.toString().padLeft(2, '0')}:${endDt.minute.toString().padLeft(2, '0')}';

        unifiedList.add(RoutineTask(
          id: 'auto_namaz_${pName}_${date.year}_${date.month}_${date.day}',
          title: '🕌 ${pName.toUpperCase()} Prayer',
          startTime: timeStr,
          endTime: endTimeStr,
          category: 'Spiritual',
          priority: 'High',
          colorHex: '#009688',
          source: 'namaz',
        ));
      }
    } catch (e) {
      debugPrint('Error pulling Namaz times for timetable: $e');
    }

    // 3. Auto-pull Calendar Events for date
    try {
      final allEvents = await _calendarService.getUserEvents(uid);
      final holidays = _calendarService.getNationalHolidays(date.year);
      final islamic = _calendarService.getIslamicEvents(date.year);
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final dayEvents = [...allEvents, ...holidays, ...islamic].where((e) {
        if (e.repeatType == 'yearly') {
          final p = e.date.split('-');
          return p.length == 3 && int.parse(p[1]) == date.month && int.parse(p[2]) == date.day;
        }
        return e.date == dateStr;
      }).toList();

      for (final event in dayEvents) {
        final parts = event.time.split(':');
        int h = 9;
        int m = 0;
        if (parts.length == 2) {
          h = int.parse(parts[0]);
          m = int.parse(parts[1]);
        }
        final endH = (h + 1) % 24;
        final endTimeStr = '${endH.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

        unifiedList.add(RoutineTask(
          id: 'auto_cal_${event.id}',
          title: '📅 ${event.title}',
          startTime: event.time,
          endTime: endTimeStr,
          category: event.category,
          priority: event.priority,
          colorHex: event.colorHex,
          isCompleted: event.isCompleted,
          source: 'calendar',
        ));
      }
    } catch (e) {
      debugPrint('Error pulling Calendar events for timetable: $e');
    }

    // Sort chronologically by startTime
    unifiedList.sort((a, b) => a.startTime.compareTo(b.startTime));
    return unifiedList;
  }
}
