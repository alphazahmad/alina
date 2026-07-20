import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'auth_service.dart';

/// Central sync manager.
/// • Tracks last-sync time.
/// • Provides syncAll(uid) to push all local data to Firebase.
/// • Exposes [isSyncing] ChangeNotifier for UI.
class SyncManager extends ChangeNotifier {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  bool _isSyncing = false;
  String _lastSyncTime = 'Never';
  String _syncStatus = '';
  int _syncedItems = 0;
  int _failedItems = 0;

  bool get isSyncing => _isSyncing;
  String get lastSyncTime => _lastSyncTime;
  String get syncStatus => _syncStatus;
  int get syncedItems => _syncedItems;
  int get failedItems => _failedItems;

  bool get isFirebaseAvailable => !AuthService().isSandboxMode;

  // ─── Last sync time persistence ────────────────────────────────────
  Future<File> _syncMetaFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/alina_sync_meta.json');
  }

  Future<void> _loadLastSyncTime() async {
    try {
      final file = await _syncMetaFile();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _lastSyncTime = data['lastSyncTime'] ?? 'Never';
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveLastSyncTime() async {
    try {
      final file = await _syncMetaFile();
      await file.writeAsString(jsonEncode({'lastSyncTime': _lastSyncTime}));
    } catch (_) {}
  }

  Future<void> init() async {
    await _loadLastSyncTime();
  }

  // ─── Main sync entry point ─────────────────────────────────────────
  Future<SyncResult> syncAll(String uid) async {
    if (_isSyncing) return SyncResult(synced: 0, failed: 0, message: 'Already syncing…');
    if (!isFirebaseAvailable) {
      return SyncResult(synced: 0, failed: 0, message: 'Firebase not connected. Check your configuration.');
    }

    _isSyncing = true;
    _syncedItems = 0;
    _failedItems = 0;
    _syncStatus = 'Starting sync…';
    notifyListeners();

    final dir = await getApplicationDocumentsDirectory();

    // ── 1. Namaz day records ────────────────────────────────────────
    _syncStatus = 'Syncing Namaz records…';
    notifyListeners();
    await _syncNamazRecords(uid, dir.path);

    // ── 2. Namaz stats summary ──────────────────────────────────────
    _syncStatus = 'Syncing Namaz stats…';
    notifyListeners();
    await _syncNamazStats(uid, dir.path);

    // ── 3. Zikr counters ────────────────────────────────────────────
    _syncStatus = 'Syncing Zikr counters…';
    notifyListeners();
    await _syncZikrCounters(uid, dir.path);

    // ── 4. Zikr history ─────────────────────────────────────────────
    _syncStatus = 'Syncing Zikr history…';
    notifyListeners();
    await _syncZikrHistory(uid, dir.path);

    // ── 5. To-Do list ───────────────────────────────────────────────
    _syncStatus = 'Syncing To-Do list…';
    notifyListeners();
    await _syncTodos(uid, dir.path);

    // ── 6. Finance records ──────────────────────────────────────────
    _syncStatus = 'Syncing Finance records…';
    notifyListeners();
    await _syncFinanceRecords(uid, dir.path);

    // ── 7. Calendar events ──────────────────────────────────────────
    _syncStatus = 'Syncing Calendar events…';
    notifyListeners();
    await _syncCalendarEvents(uid, dir.path);

    // ── 8. Routine tasks ────────────────────────────────────────────
    _syncStatus = 'Syncing Routine tasks…';
    notifyListeners();
    await _syncRoutineTasks(uid, dir.path);

    // ── 9. Profile info ─────────────────────────────────────────────
    _syncStatus = 'Syncing Profile…';
    notifyListeners();
    await _syncProfile(uid, dir.path);

    // ── Done ────────────────────────────────────────────────────────
    final now = DateTime.now();
    _lastSyncTime = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    await _saveLastSyncTime();

    _isSyncing = false;
    _syncStatus = _failedItems == 0
        ? '✅ Sync complete! $_syncedItems items uploaded.'
        : '⚠️ Sync done. $_syncedItems uploaded, $_failedItems failed.';
    notifyListeners();

    return SyncResult(synced: _syncedItems, failed: _failedItems, message: _syncStatus);
  }

  // ─── Namaz day records ─────────────────────────────────────────────
  Future<void> _syncNamazRecords(String uid, String dirPath) async {
    try {
      final dir = Directory(dirPath);
      final files = dir.listSync().whereType<File>().where(
        (f) => f.path.contains('alina_sandbox_namaz_${uid}_') && !f.path.contains('stats'),
      );

      for (final file in files) {
        try {
          final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
          final dateStr = raw['date'] as String? ?? '';
          if (dateStr.isEmpty) continue;

          await fs.FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('namaz')
              .doc(dateStr)
              .set(raw, fs.SetOptions(merge: true));
          _syncedItems++;
        } catch (e) {
          debugPrint('SyncManager: namaz day sync error: $e');
          _failedItems++;
        }
      }
    } catch (e) {
      debugPrint('SyncManager: namaz records error: $e');
    }
    notifyListeners();
  }

  // ─── Namaz stats ───────────────────────────────────────────────────
  Future<void> _syncNamazStats(String uid, String dirPath) async {
    try {
      final file = File('$dirPath/alina_sandbox_namaz_stats_$uid.json');
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        await fs.FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('namaz_stats')
            .doc('summary')
            .set(raw, fs.SetOptions(merge: true));
        _syncedItems++;
      }
    } catch (e) {
      debugPrint('SyncManager: namaz stats error: $e');
      _failedItems++;
    }
    notifyListeners();
  }

  // ─── Zikr counters ─────────────────────────────────────────────────
  Future<void> _syncZikrCounters(String uid, String dirPath) async {
    try {
      final file = File('$dirPath/alina_sandbox_counters_$uid.json');
      if (await file.exists()) {
        final List<dynamic> raw = jsonDecode(await file.readAsString());
        for (final item in raw) {
          final map = item as Map<String, dynamic>;
          final id = map['id'] as String? ?? '';
          if (id.isEmpty) continue;
          await fs.FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('counters')
              .doc(id)
              .set(map, fs.SetOptions(merge: true));
          _syncedItems++;
        }
      }
    } catch (e) {
      debugPrint('SyncManager: zikr counters error: $e');
      _failedItems++;
    }
    notifyListeners();
  }

  // ─── Zikr history ─────────────────────────────────────────────────
  Future<void> _syncZikrHistory(String uid, String dirPath) async {
    try {
      final dir = Directory(dirPath);
      final files = dir.listSync().whereType<File>().where(
        (f) => f.path.contains('alina_sandbox_history_${uid}_'),
      );

      for (final file in files) {
        try {
          // Filename: alina_sandbox_history_{uid}_{counterId}_{monthKey}.json
          final name = file.uri.pathSegments.last.replaceAll('.json', '');
          final prefix = 'alina_sandbox_history_${uid}_';
          if (!name.startsWith(prefix)) continue;
          final remainder = name.substring(prefix.length);
          // last 7 chars are yyyy-MM
          final monthKey = remainder.substring(remainder.length - 7);
          final counterId = remainder.substring(0, remainder.length - 8);
          if (counterId.isEmpty || monthKey.length < 7) continue;

          final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
          await fs.FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('counters')
              .doc(counterId)
              .collection('history')
              .doc(monthKey)
              .set(raw, fs.SetOptions(merge: true));
          _syncedItems++;
        } catch (e) {
          debugPrint('SyncManager: zikr history item error: $e');
          _failedItems++;
        }
      }
    } catch (e) {
      debugPrint('SyncManager: zikr history error: $e');
    }
    notifyListeners();
  }

  // ─── To-Do list ────────────────────────────────────────────────────
  Future<void> _syncTodos(String uid, String dirPath) async {
    try {
      final file = File('$dirPath/alina_todos_$uid.json');
      if (await file.exists()) {
        final List<dynamic> raw = jsonDecode(await file.readAsString());
        for (final item in raw) {
          final map = item as Map<String, dynamic>;
          final id = map['id'] as String? ?? '';
          if (id.isEmpty) continue;
          await fs.FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('todos')
              .doc(id)
              .set(map, fs.SetOptions(merge: true));
          _syncedItems++;
        }
      }
    } catch (e) {
      debugPrint('SyncManager: todos error: $e');
      _failedItems++;
    }
    notifyListeners();
  }

  // ─── Finance records ───────────────────────────────────────────────
  Future<void> _syncFinanceRecords(String uid, String dirPath) async {
    try {
      final dir = Directory(dirPath);
      final files = dir.listSync().whereType<File>().where(
        (f) => f.path.contains('finance_') && f.path.contains('_$uid.json'),
      );

      for (final file in files) {
        try {
          final name = file.uri.pathSegments.last.replaceAll('.json', '');
          // finance_{monthKey}_{uid} or finance_{monthKey}
          final parts = name.split('_');
          if (parts.length < 2) continue;
          // monthKey is yyyy-MM (7 chars)
          String monthKey = '';
          for (int i = 1; i < parts.length; i++) {
            final candidate = parts[i];
            if (candidate.length == 7 && candidate.contains('-')) {
              monthKey = candidate;
              break;
            }
          }
          if (monthKey.isEmpty) continue;

          final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
          await fs.FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('finance_months')
              .doc(monthKey)
              .set(raw, fs.SetOptions(merge: true));
          _syncedItems++;
        } catch (e) {
          debugPrint('SyncManager: finance item error: $e');
          _failedItems++;
        }
      }
    } catch (e) {
      debugPrint('SyncManager: finance error: $e');
    }
    notifyListeners();
  }

  // ─── Calendar events ───────────────────────────────────────────────
  Future<void> _syncCalendarEvents(String uid, String dirPath) async {
    try {
      final file = File('$dirPath/alina_sandbox_calendar_$uid.json');
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is List) {
          for (final item in raw) {
            final map = item as Map<String, dynamic>;
            final id = map['id'] as String? ?? '';
            if (id.isEmpty) continue;
            await fs.FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('calendar_events')
                .doc(id)
                .set(map, fs.SetOptions(merge: true));
            _syncedItems++;
          }
        } else if (raw is Map) {
          await fs.FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('calendar_data')
              .doc('events')
              .set(Map<String, dynamic>.from(raw), fs.SetOptions(merge: true));
          _syncedItems++;
        }
      }
    } catch (e) {
      debugPrint('SyncManager: calendar error: $e');
      _failedItems++;
    }
    notifyListeners();
  }

  // ─── Routine tasks ─────────────────────────────────────────────────
  Future<void> _syncRoutineTasks(String uid, String dirPath) async {
    try {
      final file = File('$dirPath/alina_routines_$uid.json');
      if (await file.exists()) {
        final List<dynamic> raw = jsonDecode(await file.readAsString());
        for (final item in raw) {
          final map = item as Map<String, dynamic>;
          final id = map['id'] as String? ?? '';
          if (id.isEmpty) continue;
          await fs.FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('routines')
              .doc(id)
              .set(map, fs.SetOptions(merge: true));
          _syncedItems++;
        }
      }
    } catch (e) {
      debugPrint('SyncManager: routines error: $e');
      _failedItems++;
    }
    notifyListeners();
  }

  // ─── Profile info ──────────────────────────────────────────────────
  Future<void> _syncProfile(String uid, String dirPath) async {
    try {
      final file = File('$dirPath/profile_$uid.json');
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        await fs.FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('profile')
            .doc('info')
            .set(raw, fs.SetOptions(merge: true));
        _syncedItems++;
      }
    } catch (e) {
      debugPrint('SyncManager: profile error: $e');
      _failedItems++;
    }
    notifyListeners();
  }
}

class SyncResult {
  final int synced;
  final int failed;
  final String message;
  const SyncResult({required this.synced, required this.failed, required this.message});
}
