import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'auth_service.dart';
import 'prayer_time_service.dart';

class NamazService {
  static final NamazService _instance = NamazService._internal();
  factory NamazService() => _instance;
  NamazService._internal();

  final _prayerTimeService = PrayerTimeService();
  bool get isSandboxMode => AuthService().isSandboxMode;

  static final DateTime startDate = DateTime(2015, 5, 25); // User's 12th birthday

  String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Generates the default state of a day based on whether it is in the past, today, or in the future.
  Future<Map<String, dynamic>> _generateDefaultRecord(DateTime date) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    final record = <String, dynamic>{
      'date': formatDate(date),
      'notes': '',
    };

    final prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

    if (target.isBefore(today)) {
      // In the past, default is "Not Attended"
      for (final prayer in prayers) {
        record[prayer] = 'Not Attended';
      }
    } else if (target.isAfter(today)) {
      // In the future, default is "Upcoming"
      for (final prayer in prayers) {
        record[prayer] = 'Upcoming';
      }
    } else {
      // Today: dynamic based on current time
      for (final prayer in prayers) {
        if (await _prayerTimeService.hasPrayerPassed(prayer, date)) {
          record[prayer] = 'Not Attended';
        } else {
          record[prayer] = 'Upcoming';
        }
      }
    }

    return record;
  }

  /// Loads the record for a specific day.
  Future<Map<String, dynamic>> getDayRecord(String uid, DateTime date) async {
    final dateStr = formatDate(date);
    Map<String, dynamic>? data = await _loadSandboxDayRecord(uid, dateStr);

    if (data == null && !isSandboxMode) {
      try {
        final doc = await fs.FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('namaz')
            .doc(dateStr)
            .get();
        if (doc.exists) {
          data = doc.data();
          if (data != null) {
            await _saveSandboxDayRecord(uid, dateStr, data);
          }
        }
      } catch (e) {
        // Fallback to cache if offline
        try {
          final doc = await fs.FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('namaz')
              .doc(dateStr)
              .get(const fs.GetOptions(source: fs.Source.cache));
          if (doc.exists) {
            data = doc.data();
          }
        } catch (_) {}
      }
    }

    if (data == null) {
      return await _generateDefaultRecord(date);
    }

    // Dynamic update for Today's upcoming prayers whose times have passed
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      bool modified = false;
      for (final prayer in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
        if (data[prayer] == 'Upcoming' && await _prayerTimeService.hasPrayerPassed(prayer, date)) {
          data[prayer] = 'Not Attended';
          modified = true;
        }
      }
      if (modified) {
        await saveDayRecord(uid, date, data, isAutoUpdate: true);
      }
    }

    return data;
  }

  /// Saves the record for a specific day, recalculating lifetime stats incrementally.
  Future<void> saveDayRecord(String uid, DateTime date, Map<String, dynamic> newRecord, {bool isAutoUpdate = false}) async {
    final dateStr = formatDate(date);
    
    // 1. Get old record to compute delta for stats
    final oldRecord = await getDayRecord(uid, date);
    
    // 2. Always save locally first (offline-first)
    await _saveSandboxDayRecord(uid, dateStr, newRecord);

    // Also push to Firebase in background if connected
    if (!isSandboxMode) {
      fs.FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('namaz')
          .doc(dateStr)
          .set(newRecord)
          .catchError((e) => debugPrint('Namaz Firebase sync error: $e'));
    }

    // 3. Compute stats delta and update summary (skip delta math if it's just an automated background update)
    if (!isAutoUpdate) {
      await _updateNamazStats(uid, oldRecord, newRecord);
    }
  }

  /// Loads the lifetime stats summary.
  Future<Map<String, dynamic>> getStatsSummary(String uid) async {
    Map<String, dynamic>? data = await _loadSandboxStatsSummary(uid);

    if (data == null && !isSandboxMode) {
      try {
        final doc = await fs.FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('namaz_stats')
            .doc('summary')
            .get();
        if (doc.exists) {
          data = doc.data();
          if (data != null) {
            await _saveSandboxStatsSummary(uid, data);
          }
        }
      } catch (e) {
        try {
          final doc = await fs.FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('namaz_stats')
              .doc('summary')
              .get(const fs.GetOptions(source: fs.Source.cache));
          if (doc.exists) {
            data = doc.data();
          }
        } catch (_) {}
      }
    }

    if (data == null) {
      // Initialize stats since 25-05-2015
      final today = DateTime.now();
      final totalDays = today.difference(startDate).inDays.clamp(0, 99999);
      final totalPrayers = totalDays * 5;

      data = {
        'totalAttended': 0,
        'totalQaza': 0,
        'totalNotAttended': totalPrayers,
        'streakDays': 0,
        'relationshipLevel': 1,
        'lovePoints': 10,
        'alinaMood': 'Happy 💖',
      };

      // Save initial summary
      await _saveStatsSummary(uid, data);
    }

    return data;
  }

  /// Recalculates stats summaries based on a changed day record.
  Future<void> _updateNamazStats(String uid, Map<String, dynamic> oldRecord, Map<String, dynamic> newRecord) async {
    final stats = await getStatsSummary(uid);
    
    int attendedDelta = 0;
    int qazaDelta = 0;
    int notAttendedDelta = 0;

    final prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    for (final prayer in prayers) {
      final oldStatus = oldRecord[prayer] ?? 'Upcoming';
      final newStatus = newRecord[prayer] ?? 'Upcoming';

      if (oldStatus == newStatus) continue;

      // Subtract old status
      if (oldStatus == 'Attended') attendedDelta--;
      if (oldStatus == 'Qaza') qazaDelta--;
      if (oldStatus == 'Not Attended') notAttendedDelta--;

      // Add new status
      if (newStatus == 'Attended') attendedDelta++;
      if (newStatus == 'Qaza') qazaDelta++;
      if (newStatus == 'Not Attended') notAttendedDelta++;
    }

    stats['totalAttended'] = (stats['totalAttended'] + attendedDelta).clamp(0, 999999);
    stats['totalQaza'] = (stats['totalQaza'] + qazaDelta).clamp(0, 999999);
    stats['totalNotAttended'] = (stats['totalNotAttended'] + notAttendedDelta).clamp(0, 999999);

    // Compute active streak (consecutive days preceding today where all 5 prayers were completed: Attended or Qaza)
    final streak = await _calculateActiveStreak(uid);
    stats['streakDays'] = streak;

    // Gamified relationship rewards for logging prayers
    if (attendedDelta > 0) {
      int lovePoints = stats['lovePoints'] ?? 10;
      int relationshipLevel = stats['relationshipLevel'] ?? 1;

      lovePoints = (lovePoints + (attendedDelta * 4)).clamp(0, 100);
      if (lovePoints == 100 && relationshipLevel < 10) {
        relationshipLevel++;
        lovePoints = 10;
      }
      stats['lovePoints'] = lovePoints;
      stats['relationshipLevel'] = relationshipLevel;
    }

    // Dynamic moods based on streak
    if (streak >= 15) {
      stats['alinaMood'] = 'Proud 😍';
    } else if (streak >= 7) {
      stats['alinaMood'] = 'Inspired 🥰';
    } else if (streak >= 3) {
      stats['alinaMood'] = 'Happy 💖';
    } else {
      stats['alinaMood'] = 'Caring 💙';
    }

    await _saveStatsSummary(uid, stats);
  }

  Future<int> _calculateActiveStreak(String uid) async {
    int streak = 0;
    final now = DateTime.now();
    
    // Check in 7-day parallel batches for maximum speed
    for (int batch = 0; batch < 52; batch++) {
      final List<DateTime> batchDates = [];
      for (int i = 0; i < 7; i++) {
        final dayIndex = batch * 7 + i;
        final checkDate = now.subtract(Duration(days: dayIndex));
        if (checkDate.isBefore(startDate)) break;
        batchDates.add(checkDate);
      }

      if (batchDates.isEmpty) break;

      final batchRecords = await Future.wait(
        batchDates.map((d) => getDayRecord(uid, d)),
      );

      bool broken = false;
      for (int i = 0; i < batchDates.length; i++) {
        final dayIndex = batch * 7 + i;
        final record = batchRecords[i];

        bool allCompleted = true;
        for (final prayer in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
          final status = record[prayer] ?? 'Upcoming';
          if (dayIndex == 0 && status == 'Upcoming') continue;
          if (status != 'Attended' && status != 'Qaza') {
            allCompleted = false;
            break;
          }
        }

        if (allCompleted) {
          streak++;
        } else {
          if (dayIndex == 0) continue;
          broken = true;
          break;
        }
      }

      if (broken) break;
    }
    return streak;
  }

  Future<void> _saveStatsSummary(String uid, Map<String, dynamic> summary) async {
    // Always save locally
    await _saveSandboxStatsSummary(uid, summary);

    // Also push to Firebase in background if connected
    if (!isSandboxMode) {
      fs.FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('namaz_stats')
          .doc('summary')
          .set(summary)
          .catchError((e) => debugPrint('NamazStats Firebase sync error: $e'));
    }
  }

  // --- Sandbox storage implementations ---

  Future<Map<String, dynamic>?> _loadSandboxDayRecord(String uid, String dateStr) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alina_sandbox_namaz_${uid}_$dateStr.json');
      if (await file.exists()) {
        return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error loading sandbox namaz day: $e');
    }
    return null;
  }

  Future<void> _saveSandboxDayRecord(String uid, String dateStr, Map<String, dynamic> record) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alina_sandbox_namaz_${uid}_$dateStr.json');
      await file.writeAsString(jsonEncode(record));
    } catch (e) {
      debugPrint('Error saving sandbox namaz day: $e');
    }
  }

  Future<Map<String, dynamic>?> _loadSandboxStatsSummary(String uid) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alina_sandbox_namaz_stats_$uid.json');
      if (await file.exists()) {
        return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error loading sandbox stats summary: $e');
    }
    return null;
  }

  Future<void> _saveSandboxStatsSummary(String uid, Map<String, dynamic> summary) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alina_sandbox_namaz_stats_$uid.json');
      await file.writeAsString(jsonEncode(summary));
    } catch (e) {
      debugPrint('Error saving sandbox stats summary: $e');
    }
  }
}
