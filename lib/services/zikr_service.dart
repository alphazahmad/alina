import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'auth_service.dart';

class ZikrCounter {
  final String id;
  final String name;
  final String iconName;
  final bool hasTarget;
  final int targetValue;
  final bool isPinned;
  int dailyCount;
  int monthlyCount;
  int lifetimeCount;
  String lastUpdatedDate; // yyyy-MM-dd
  String lastUpdatedMonth; // yyyy-MM
  Map<String, int> currentMonthLogs; // yyyy-MM-dd -> count

  ZikrCounter({
    required this.id,
    required this.name,
    required this.iconName,
    required this.hasTarget,
    required this.targetValue,
    required this.isPinned,
    required this.dailyCount,
    required this.monthlyCount,
    required this.lifetimeCount,
    required this.lastUpdatedDate,
    required this.lastUpdatedMonth,
    required this.currentMonthLogs,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconName': iconName,
      'hasTarget': hasTarget,
      'targetValue': targetValue,
      'isPinned': isPinned,
      'dailyCount': dailyCount,
      'monthlyCount': monthlyCount,
      'lifetimeCount': lifetimeCount,
      'lastUpdatedDate': lastUpdatedDate,
      'lastUpdatedMonth': lastUpdatedMonth,
      'currentMonthLogs': currentMonthLogs,
    };
  }

  factory ZikrCounter.fromMap(Map<String, dynamic> map) {
    // Safety check map casts
    final logsMap = map['currentMonthLogs'] as Map<dynamic, dynamic>? ?? {};
    final Map<String, int> castedLogs = {};
    logsMap.forEach((k, v) {
      castedLogs[k.toString()] = (v as num).toInt();
    });

    return ZikrCounter(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      iconName: map['iconName'] ?? 'circle_outlined',
      hasTarget: map['hasTarget'] ?? false,
      targetValue: (map['targetValue'] ?? 0) as int,
      isPinned: map['isPinned'] ?? false,
      dailyCount: (map['dailyCount'] ?? 0) as int,
      monthlyCount: (map['monthlyCount'] ?? 0) as int,
      lifetimeCount: (map['lifetimeCount'] ?? 0) as int,
      lastUpdatedDate: map['lastUpdatedDate'] ?? '',
      lastUpdatedMonth: map['lastUpdatedMonth'] ?? '',
      currentMonthLogs: castedLogs,
    );
  }
}

class ZikrService {
  static final ZikrService _instance = ZikrService._internal();
  factory ZikrService() => _instance;
  ZikrService._internal();

  bool get isSandboxMode => AuthService().isSandboxMode;

  String _getTodayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _getMonthStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Lazy reset handler to clear daily/monthly counters when date shifts.
  Future<ZikrCounter> _lazyResetCounterIfNeeded(String uid, ZikrCounter counter) async {
    final todayStr = _getTodayStr();
    final monthStr = _getMonthStr();
    bool modified = false;

    // 1. Check Monthly Reset
    if (counter.lastUpdatedMonth != monthStr && counter.lastUpdatedMonth.isNotEmpty) {
      // Archive historical month log
      await _archiveMonthlyHistory(uid, counter.id, counter.lastUpdatedMonth, counter.monthlyCount, counter.currentMonthLogs);
      
      counter.monthlyCount = 0;
      counter.currentMonthLogs = {};
      counter.lastUpdatedMonth = monthStr;
      modified = true;
    }

    // 2. Check Daily Reset
    if (counter.lastUpdatedDate != todayStr) {
      counter.dailyCount = 0;
      counter.lastUpdatedDate = todayStr;
      if (counter.lastUpdatedMonth.isEmpty) {
        counter.lastUpdatedMonth = monthStr;
      }
      modified = true;
    }

    if (modified) {
      await saveCounter(uid, counter);
    }

    return counter;
  }

  /// Get list of all counters for a user (capped at 10)
  Future<List<ZikrCounter>> getCounters(String uid) async {
    List<ZikrCounter> list = await _loadSandboxCounters(uid);

    if (list.isEmpty && !isSandboxMode) {
      try {
        final query = await fs.FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('counters')
            .get();
        list = query.docs.map((doc) => ZikrCounter.fromMap(doc.data())).toList();
        // Cache them locally
        for (final c in list) {
          await _saveSandboxCounter(uid, c);
        }
      } catch (e) {
        try {
          final query = await fs.FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('counters')
              .get(const fs.GetOptions(source: fs.Source.cache));
          list = query.docs.map((doc) => ZikrCounter.fromMap(doc.data())).toList();
        } catch (_) {}
      }
    }

    // Perform lazy resets and sort: Pinned first, then by name
    for (int i = 0; i < list.length; i++) {
      list[i] = await _lazyResetCounterIfNeeded(uid, list[i]);
    }

    list.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return a.name.compareTo(b.name);
    });

    return list;
  }

  /// Save or update a counter
  Future<void> saveCounter(String uid, ZikrCounter counter) async {
    // Always save locally first
    await _saveSandboxCounter(uid, counter);

    // Also push to Firebase in background if connected
    if (!isSandboxMode) {
      fs.FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('counters')
          .doc(counter.id)
          .set(counter.toMap())
          .catchError((e) => debugPrint('Zikr counter Firebase sync error: $e'));
    }
  }

  /// Increment counter
  Future<void> incrementCounter(String uid, String counterId) async {
    final list = await getCounters(uid);
    final index = list.indexWhere((c) => c.id == counterId);
    if (index == -1) return;

    final counter = list[index];
    final todayStr = _getTodayStr();
    final monthStr = _getMonthStr();

    counter.dailyCount++;
    counter.monthlyCount++;
    counter.lifetimeCount++;
    counter.lastUpdatedDate = todayStr;
    counter.lastUpdatedMonth = monthStr;

    // Increment today's count in current month logs
    final todayLog = counter.currentMonthLogs[todayStr] ?? 0;
    counter.currentMonthLogs[todayStr] = todayLog + 1;

    await saveCounter(uid, counter);
  }

  /// Delete a counter
  Future<void> deleteCounter(String uid, String counterId) async {
    // Always delete locally first
    await _deleteSandboxCounter(uid, counterId);

    // Also delete from Firebase if connected
    if (!isSandboxMode) {
      try {
        final docRef = fs.FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('counters')
            .doc(counterId);
        await docRef.delete();
        final historyQuery = await docRef.collection('history').get();
        for (final doc in historyQuery.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('Zikr delete Firebase sync error: $e');
      }
    }
  }

  /// Retrieve archived monthly history docs
  Future<Map<String, dynamic>?> getMonthlyHistory(String uid, String counterId, String monthKey) async {
    Map<String, dynamic>? data = await _loadSandboxHistory(uid, counterId, monthKey);

    if (data == null && !isSandboxMode) {
      try {
        final doc = await fs.FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('counters')
            .doc(counterId)
            .collection('history')
            .doc(monthKey)
            .get();
        if (doc.exists) {
          data = doc.data();
          if (data != null) {
            await _saveSandboxHistory(uid, counterId, monthKey, data);
          }
        }
      } catch (_) {}
    }
    return data;
  }

  /// Save archived historical month logs
  Future<void> _archiveMonthlyHistory(String uid, String counterId, String monthKey, int total, Map<String, int> dailyLogs) async {
    final historyData = {
      'month': monthKey,
      'totalCount': total,
      'dailyLogs': dailyLogs,
    };

    // Always save locally
    await _saveSandboxHistory(uid, counterId, monthKey, historyData);

    // Also push to Firebase in background if connected
    if (!isSandboxMode) {
      fs.FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('counters')
          .doc(counterId)
          .collection('history')
          .doc(monthKey)
          .set(historyData)
          .catchError((e) => debugPrint('Zikr history Firebase sync error: $e'));
    }
  }

  // --- Sandbox local file storage implementations ---

  Future<List<ZikrCounter>> _loadSandboxCounters(String uid) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alina_sandbox_counters_$uid.json');
      if (await file.exists()) {
        final List<dynamic> jsonList = jsonDecode(await file.readAsString()) as List<dynamic>;
        return jsonList.map((map) => ZikrCounter.fromMap(map as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading sandbox counters: $e');
    }
    return [];
  }

  Future<void> _saveSandboxCounter(String uid, ZikrCounter counter) async {
    final counters = await _loadSandboxCounters(uid);
    final idx = counters.indexWhere((c) => c.id == counter.id);
    if (idx != -1) {
      counters[idx] = counter;
    } else {
      counters.add(counter);
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alina_sandbox_counters_$uid.json');
      await file.writeAsString(jsonEncode(counters.map((c) => c.toMap()).toList()));
    } catch (e) {
      debugPrint('Error saving sandbox counter: $e');
    }
  }

  Future<void> _deleteSandboxCounter(String uid, String counterId) async {
    final counters = await _loadSandboxCounters(uid);
    counters.removeWhere((c) => c.id == counterId);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alina_sandbox_counters_$uid.json');
      await file.writeAsString(jsonEncode(counters.map((c) => c.toMap()).toList()));
      
      // Clean up sandbox history files for this counter
      final files = dir.listSync();
      for (final f in files) {
        if (f.path.contains('alina_sandbox_history_${uid}_${counterId}_')) {
          await f.delete();
        }
      }
    } catch (e) {
      debugPrint('Error deleting sandbox counter: $e');
    }
  }

  Future<Map<String, dynamic>?> _loadSandboxHistory(String uid, String counterId, String monthKey) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alina_sandbox_history_${uid}_${counterId}_$monthKey.json');
      if (await file.exists()) {
        return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error loading sandbox history: $e');
    }
    return null;
  }

  Future<void> _saveSandboxHistory(String uid, String counterId, String monthKey, Map<String, dynamic> historyData) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alina_sandbox_history_${uid}_${counterId}_$monthKey.json');
      await file.writeAsString(jsonEncode(historyData));
    } catch (e) {
      debugPrint('Error saving sandbox history: $e');
    }
  }
}
