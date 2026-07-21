import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final String date; // yyyy-MM-dd
  final String time; // HH:mm
  final String type; // 'temporary', 'recurring', 'holiday', 'islamic', 'namaz', 'finance'
  final String category; // 'Personal', 'Work', 'Spiritual', 'Holiday', 'Finance', 'Other'
  final String priority; // 'High', 'Medium', 'Low'
  final String colorHex;
  final bool isCompleted;
  final String repeatType; // 'none', 'yearly', 'monthly', 'weekly'
  final String reminderTime; // 'None', 'At event time', '15 mins before', '1 hour before', '1 day before'

  CalendarEvent({
    required this.id,
    required this.title,
    this.description = '',
    required this.date,
    this.time = '09:00',
    this.type = 'temporary',
    this.category = 'Personal',
    this.priority = 'Medium',
    this.colorHex = '#F52670',
    this.isCompleted = false,
    this.repeatType = 'none',
    this.reminderTime = 'None',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'time': time,
      'type': type,
      'category': category,
      'priority': priority,
      'colorHex': colorHex,
      'isCompleted': isCompleted,
      'repeatType': repeatType,
      'reminderTime': reminderTime,
    };
  }

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: map['date'] ?? '',
      time: map['time'] ?? '09:00',
      type: map['type'] ?? 'temporary',
      category: map['category'] ?? 'Personal',
      priority: map['priority'] ?? 'Medium',
      colorHex: map['colorHex'] ?? '#F52670',
      isCompleted: map['isCompleted'] ?? false,
      repeatType: map['repeatType'] ?? 'none',
      reminderTime: map['reminderTime'] ?? 'None',
    );
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    String? date,
    String? time,
    String? type,
    String? category,
    String? priority,
    String? colorHex,
    bool? isCompleted,
    String? repeatType,
    String? reminderTime,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      time: time ?? this.time,
      type: type ?? this.type,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      colorHex: colorHex ?? this.colorHex,
      isCompleted: isCompleted ?? this.isCompleted,
      repeatType: repeatType ?? this.repeatType,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
}

class CalendarService {
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();

  static const List<String> categories = ['Personal', 'Work', 'Spiritual', 'Holiday', 'Finance', 'Other'];
  static const List<String> priorities = ['High', 'Medium', 'Low'];
  static const List<String> repeatOptions = ['none', 'yearly', 'monthly', 'weekly'];
  static const List<String> reminderOptions = ['None', 'At event time', '15 mins before', '1 hour before', '1 day before'];

  bool get _isFirebaseAvailable {
    try {
      return FirebaseFirestore.instance.app.name.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<File> _getLocalFile(String uid) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/calendar_events_$uid.json');
  }

  // --- CRUD Operations ---

  Future<List<CalendarEvent>> getUserEvents(String uid) async {
    List<CalendarEvent> localEvents = [];
    try {
      final file = await _getLocalFile(uid);
      if (await file.exists()) {
        final content = await file.readAsString();
        final List list = jsonDecode(content);
        localEvents = list.map((item) => CalendarEvent.fromMap(item)).toList();
      }
    } catch (e) {
      debugPrint('Error loading sandbox calendar file: $e');
    }

    if (localEvents.isNotEmpty) {
      return localEvents;
    }

    if (_isFirebaseAvailable) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('calendar_events')
            .get().timeout(const Duration(seconds: 2));

        final remoteEvents = snap.docs.map((doc) => CalendarEvent.fromMap(doc.data())).toList();
        // Cache locally
        try {
          final file = await _getLocalFile(uid);
          await file.writeAsString(jsonEncode(remoteEvents.map((e) => e.toMap()).toList()));
        } catch (_) {}
        return remoteEvents;
      } catch (e) {
        debugPrint('Error loading events from Firestore: $e');
      }
    }

    return localEvents;
  }

  Future<void> addOrUpdateEvent(String uid, CalendarEvent event) async {
    if (_isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('calendar_events')
            .doc(event.id)
            .set(event.toMap());
      } catch (e) {
        debugPrint('Error saving event to Firestore: $e');
      }
    }

    // Always mirror to Sandbox
    try {
      final events = await getUserEvents(uid);
      final index = events.indexWhere((e) => e.id == event.id);
      if (index >= 0) {
        events[index] = event;
      } else {
        events.add(event);
      }
      final file = await _getLocalFile(uid);
      await file.writeAsString(jsonEncode(events.map((e) => e.toMap()).toList()));
    } catch (e) {
      debugPrint('Error saving sandbox event: $e');
    }
  }

  Future<void> deleteEvent(String uid, String eventId) async {
    if (_isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('calendar_events')
            .doc(eventId)
            .delete();
      } catch (e) {
        debugPrint('Error deleting event from Firestore: $e');
      }
    }

    try {
      final events = await getUserEvents(uid);
      events.removeWhere((e) => e.id == eventId);
      final file = await _getLocalFile(uid);
      await file.writeAsString(jsonEncode(events.map((e) => e.toMap()).toList()));
    } catch (e) {
      debugPrint('Error updating sandbox events after delete: $e');
    }
  }

  Future<void> toggleEventCompleted(String uid, CalendarEvent event) async {
    final updated = event.copyWith(isCompleted: !event.isCompleted);
    await addOrUpdateEvent(uid, updated);
  }

  // --- Automatic National Holidays & Festivals Generator ---

  List<CalendarEvent> getNationalHolidays(int year) {
    final yStr = year.toString();
    return [
      CalendarEvent(
        id: 'holiday_newyear_$year',
        title: '🎉 New Year\'s Day',
        description: 'Global New Year Celebration',
        date: '$yStr-01-01',
        type: 'holiday',
        category: 'Holiday',
        colorHex: '#3F51B5',
      ),
      CalendarEvent(
        id: 'holiday_republic_$year',
        title: '🇮🇳 Republic Day',
        description: 'National Holiday of India',
        date: '$yStr-01-26',
        type: 'holiday',
        category: 'Holiday',
        colorHex: '#FF9800',
      ),
      CalendarEvent(
        id: 'holiday_independence_$year',
        title: '🇮🇳 Independence Day',
        description: 'National Freedom Day Celebration',
        date: '$yStr-08-15',
        type: 'holiday',
        category: 'Holiday',
        colorHex: '#4CAF50',
      ),
      CalendarEvent(
        id: 'holiday_gandhi_$year',
        title: '🕊️ Gandhi Jayanti',
        description: 'Mahatma Gandhi Birth Anniversary',
        date: '$yStr-10-02',
        type: 'holiday',
        category: 'Holiday',
        colorHex: '#009688',
      ),
      CalendarEvent(
        id: 'holiday_christmas_$year',
        title: '🎄 Christmas Day',
        description: 'Global Christmas Celebration',
        date: '$yStr-12-25',
        type: 'holiday',
        category: 'Holiday',
        colorHex: '#E91E63',
      ),
    ];
  }

  // --- Automatic Islamic Key Dates & Hijri Converter ---

  Map<String, dynamic> getHijriDetails(DateTime gDate) {
    int y = gDate.year;
    int m = gDate.month;
    int d = gDate.day;

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

    final islamicMonths = [
      'Muharram', 'Safar', 'Rabi\' al-Awwal', 'Rabi\' al-Thani',
      'Jumada al-Awwal', 'Jumada al-Thani', 'Rajab', 'Sha\'ban',
      'Ramadan', 'Shawwal', 'Dhu al-Qi\'dah', 'Dhu al-Hijjah'
    ];

    final monthName = islamicMonths[hMonth - 1];
    final formatted = '$hDay $monthName $hYear AH';

    return {
      'day': hDay,
      'month': hMonth,
      'monthName': monthName,
      'year': hYear,
      'formatted': formatted,
    };
  }

  List<CalendarEvent> getIslamicEvents(int year) {
    final List<CalendarEvent> events = [];
    final startDate = DateTime(year, 1, 1);
    final endDate = DateTime(year, 12, 31);

    for (var date = startDate; date.isBefore(endDate.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      final h = getHijriDetails(date);
      final hDay = h['day'] as int;
      final hMonth = h['month'] as int;
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      if (hMonth == 1 && hDay == 10) {
        events.add(CalendarEvent(
          id: 'islamic_ashura_$dateStr',
          title: '🕌 Youm-e-Ashura (10 Muharram)',
          description: 'Sacred Day of Ashura',
          date: dateStr,
          type: 'islamic',
          category: 'Spiritual',
          colorHex: '#009688',
        ));
      } else if (hMonth == 3 && hDay == 12) {
        events.add(CalendarEvent(
          id: 'islamic_eid_milad_$dateStr',
          title: '💚 Eid Milad-un-Nabi (12 Rabi-ul-Awwal)',
          description: 'Mawlid an-Nabi Celebration',
          date: dateStr,
          type: 'islamic',
          category: 'Spiritual',
          colorHex: '#4CAF50',
        ));
      } else if (hMonth == 9 && hDay == 1) {
        events.add(CalendarEvent(
          id: 'islamic_ramadan_$dateStr',
          title: '🌙 1st Ramadan Mubarak',
          description: 'Beginning of the Holy Month of Fasting',
          date: dateStr,
          type: 'islamic',
          category: 'Spiritual',
          colorHex: '#9C27B0',
        ));
      } else if (hMonth == 10 && hDay == 1) {
        events.add(CalendarEvent(
          id: 'islamic_eid_fitr_$dateStr',
          title: '✨ Eid-ul-Fitr Mubarak',
          description: 'Blessed Celebration of Eid-ul-Fitr',
          date: dateStr,
          type: 'islamic',
          category: 'Spiritual',
          colorHex: '#F52670',
        ));
      } else if (hMonth == 12 && hDay == 10) {
        events.add(CalendarEvent(
          id: 'islamic_eid_adha_$dateStr',
          title: '🐑 Eid-ul-Adha Mubarak',
          description: 'Blessed Celebration of Eid-ul-Adha',
          date: dateStr,
          type: 'islamic',
          category: 'Spiritual',
          colorHex: '#FF9800',
        ));
      }
    }

    return events;
  }
}
