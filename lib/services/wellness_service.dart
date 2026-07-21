import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// ─── Meal State ──────────────────────────────────────────────────────────────
enum MealState { pending, eaten, missed }

// ─── Sleep Quality ───────────────────────────────────────────────────────────
enum SleepQuality { none, poor, fair, good, excellent }

extension SleepQualityExt on SleepQuality {
  String get label {
    switch (this) {
      case SleepQuality.poor:      return 'Poor';
      case SleepQuality.fair:      return 'Fair';
      case SleepQuality.good:      return 'Good';
      case SleepQuality.excellent: return 'Excellent';
      default:                     return '';
    }
  }
  String get emoji {
    switch (this) {
      case SleepQuality.poor:      return '😴';
      case SleepQuality.fair:      return '🙂';
      case SleepQuality.good:      return '😊';
      case SleepQuality.excellent: return '🤩';
      default:                     return '';
    }
  }
}

// ─── Wellness Data ───────────────────────────────────────────────────────────
class WellnessData {
  // Water
  final int waterGlasses;     // filled glasses today
  final int waterGoal;        // default 8

  // Meals — map of meal key → MealState
  final Map<String, MealState> mealStates;

  // Sleep
  final String? bedtime;      // ISO8601 timestamp
  final String? wakeTime;     // ISO8601 timestamp
  final bool isSleeping;
  final SleepQuality sleepQuality;
  final int sleepGoalMinutes; // default 480 (8h)

  // XP & Streak
  final int xp;
  final int streak;
  final String lastActiveDate; // 'YYYY-MM-DD'

  // Weekly activity (last 7 days, newest first)
  final List<bool> weeklyActivity;

  const WellnessData({
    this.waterGlasses = 0,
    this.waterGoal = 8,
    this.mealStates = const {},
    this.bedtime,
    this.wakeTime,
    this.isSleeping = false,
    this.sleepQuality = SleepQuality.none,
    this.sleepGoalMinutes = 480,
    this.xp = 0,
    this.streak = 0,
    this.lastActiveDate = '',
    this.weeklyActivity = const [false, false, false, false, false, false, false],
  });

  // ── Computed ───────────────────────────────────────────────────────
  int get level => (xp / 100).floor() + 1;
  int get xpInCurrentLevel => xp % 100;
  double get xpProgress => xpInCurrentLevel / 100.0;

  Duration get sleepDuration {
    if (bedtime == null || wakeTime == null) return Duration.zero;
    try {
      final bed  = DateTime.parse(bedtime!);
      final wake = DateTime.parse(wakeTime!);
      return wake.isAfter(bed) ? wake.difference(bed) : Duration.zero;
    } catch (_) {
      return Duration.zero;
    }
  }

  double get sleepProgress {
    final mins = sleepDuration.inMinutes;
    if (mins <= 0) return 0.0;
    return (mins / sleepGoalMinutes).clamp(0.0, 1.0);
  }

  String get sleepDurationLabel {
    final d = sleepDuration;
    if (d == Duration.zero) return '--';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m}m';
  }

  Map<String, dynamic> toMap() => {
    'waterGlasses':     waterGlasses,
    'waterGoal':        waterGoal,
    'mealStates':       mealStates.map((k, v) => MapEntry(k, v.index)),
    'bedtime':          bedtime,
    'wakeTime':         wakeTime,
    'isSleeping':       isSleeping,
    'sleepQuality':     sleepQuality.index,
    'sleepGoalMinutes': sleepGoalMinutes,
    'xp':               xp,
    'streak':           streak,
    'lastActiveDate':   lastActiveDate,
    'weeklyActivity':   weeklyActivity,
  };

  factory WellnessData.fromMap(Map<String, dynamic> m) {
    final rawMeals = m['mealStates'] as Map<String, dynamic>? ?? {};
    final meals = rawMeals.map((k, v) =>
        MapEntry(k, MealState.values[(v as int).clamp(0, MealState.values.length - 1)]));

    final rawWeekly = m['weeklyActivity'];
    final weekly = rawWeekly is List
        ? rawWeekly.map((e) => e == true).toList()
        : List<bool>.filled(7, false);
    while (weekly.length < 7) { weekly.add(false); }

    return WellnessData(
      waterGlasses:     (m['waterGlasses'] as int?) ?? 0,
      waterGoal:        (m['waterGoal'] as int?) ?? 8,
      mealStates:       meals,
      bedtime:          m['bedtime'] as String?,
      wakeTime:         m['wakeTime'] as String?,
      isSleeping:       (m['isSleeping'] as bool?) ?? false,
      sleepQuality:     SleepQuality.values[((m['sleepQuality'] as int?) ?? 0)
          .clamp(0, SleepQuality.values.length - 1)],
      sleepGoalMinutes: (m['sleepGoalMinutes'] as int?) ?? 480,
      xp:               (m['xp'] as int?) ?? 0,
      streak:           (m['streak'] as int?) ?? 0,
      lastActiveDate:   (m['lastActiveDate'] as String?) ?? '',
      weeklyActivity:   weekly,
    );
  }

  WellnessData copyWith({
    int? waterGlasses,
    int? waterGoal,
    Map<String, MealState>? mealStates,
    String? bedtime,
    String? wakeTime,
    bool? isSleeping,
    SleepQuality? sleepQuality,
    int? sleepGoalMinutes,
    int? xp,
    int? streak,
    String? lastActiveDate,
    List<bool>? weeklyActivity,
    bool clearBedtime = false,
    bool clearWakeTime = false,
  }) =>
      WellnessData(
        waterGlasses:     waterGlasses     ?? this.waterGlasses,
        waterGoal:        waterGoal        ?? this.waterGoal,
        mealStates:       mealStates       ?? this.mealStates,
        bedtime:          clearBedtime     ? null : (bedtime ?? this.bedtime),
        wakeTime:         clearWakeTime    ? null : (wakeTime ?? this.wakeTime),
        isSleeping:       isSleeping       ?? this.isSleeping,
        sleepQuality:     sleepQuality     ?? this.sleepQuality,
        sleepGoalMinutes: sleepGoalMinutes ?? this.sleepGoalMinutes,
        xp:               xp               ?? this.xp,
        streak:           streak           ?? this.streak,
        lastActiveDate:   lastActiveDate   ?? this.lastActiveDate,
        weeklyActivity:   weeklyActivity   ?? this.weeklyActivity,
      );
}

// ─── Meal Definition ─────────────────────────────────────────────────────────
class MealDef {
  final String key;
  final String name;
  final String emoji;
  final String time;
  final String icon;

  const MealDef({
    required this.key,
    required this.name,
    required this.emoji,
    required this.time,
    required this.icon,
  });
}

// ─── Wellness Service ─────────────────────────────────────────────────────────
class WellnessService {
  static final WellnessService _instance = WellnessService._internal();
  factory WellnessService() => _instance;
  WellnessService._internal();

  static const List<MealDef> meals = [
    MealDef(key: 'breakfast', name: 'Breakfast', emoji: '🍳', time: '08:00', icon: '🌅'),
    MealDef(key: 'lunch',     name: 'Lunch',     emoji: '🍛', time: '13:00', icon: '☀️'),
    MealDef(key: 'snack',     name: 'Snack',     emoji: '🍎', time: '17:00', icon: '🌇'),
    MealDef(key: 'dinner',    name: 'Dinner',    emoji: '🍲', time: '21:00', icon: '🌙'),
  ];

  // ── XP Rules ───────────────────────────────────────────────────────
  static const int xpPerGlass   = 5;
  static const int xpPerMeal    = 10;
  static const int xpSleepGoal  = 20;
  static const int xpStreakBonus = 50;

  // ── Persistence ────────────────────────────────────────────────────
  Future<File> _file(String uid) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/alina_wellness_$uid.json');
  }

  Future<WellnessData> load(String uid) async {
    try {
      final file = await _file(uid);
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        WellnessData data = WellnessData.fromMap(raw as Map<String, dynamic>);

        // Reset daily data if it's a new day
        final today = _today();
        if (data.lastActiveDate != today) {
          // Push today's activity into weekly history
          final hadActivity = data.waterGlasses > 0 ||
              data.mealStates.values.any((s) => s == MealState.eaten) ||
              data.sleepDuration.inMinutes >= 60;

          final weekly = [hadActivity, ...data.weeklyActivity.take(6)].toList();
          final streak = _calcStreak(data, hadActivity);
          data = WellnessData(
            waterGoal:        data.waterGoal,
            sleepGoalMinutes: data.sleepGoalMinutes,
            xp:               data.xp,
            streak:           streak,
            lastActiveDate:   today,
            weeklyActivity:   weekly,
          );
          await save(uid, data);
        }
        return data;
      }
    } catch (e) {
      debugPrint('WellnessService load error: $e');
    }
    return WellnessData(lastActiveDate: _today());
  }

  Future<void> save(String uid, WellnessData data) async {
    try {
      final file = await _file(uid);
      await file.writeAsString(jsonEncode(data.toMap()));
    } catch (e) {
      debugPrint('WellnessService save error: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────
  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  int _calcStreak(WellnessData prev, bool hadActivity) {
    if (!hadActivity) return 0;
    return prev.streak + 1;
  }

  // ── Water actions ──────────────────────────────────────────────────
  Future<WellnessData> addGlass(String uid, WellnessData data) async {
    if (data.waterGlasses >= data.waterGoal) return data;
    final updated = data.copyWith(
      waterGlasses: data.waterGlasses + 1,
      xp: data.xp + xpPerGlass,
      lastActiveDate: _today(),
    );
    await save(uid, updated);
    return updated;
  }

  Future<WellnessData> removeGlass(String uid, WellnessData data) async {
    if (data.waterGlasses <= 0) return data;
    final updated = data.copyWith(
      waterGlasses: data.waterGlasses - 1,
      xp: (data.xp - xpPerGlass).clamp(0, 999999),
    );
    await save(uid, updated);
    return updated;
  }

  // ── Meal actions ───────────────────────────────────────────────────
  Future<WellnessData> setMealState(
      String uid, WellnessData data, String mealKey, MealState state) async {
    final prev = data.mealStates[mealKey] ?? MealState.pending;
    int xpDelta = 0;
    if (state == MealState.eaten && prev != MealState.eaten) {
      xpDelta = xpPerMeal;
    } else if (prev == MealState.eaten && state != MealState.eaten) {
      xpDelta = -xpPerMeal;
    }
    final meals = Map<String, MealState>.from(data.mealStates);
    meals[mealKey] = state;
    final updated = data.copyWith(
      mealStates: meals,
      xp: (data.xp + xpDelta).clamp(0, 999999),
      lastActiveDate: _today(),
    );
    await save(uid, updated);
    return updated;
  }

  // ── Sleep actions ──────────────────────────────────────────────────
  Future<WellnessData> goToSleep(String uid, WellnessData data) async {
    final updated = data.copyWith(
      bedtime: DateTime.now().toIso8601String(),
      isSleeping: true,
      clearWakeTime: true,
      sleepQuality: SleepQuality.none,
      lastActiveDate: _today(),
    );
    await save(uid, updated);
    return updated;
  }

  Future<WellnessData> wakeUp(String uid, WellnessData data) async {
    final wakeTime = DateTime.now().toIso8601String();
    final wakeData = data.copyWith(
      wakeTime: wakeTime,
      isSleeping: false,
    );
    // Award XP for meeting sleep goal
    final xpBonus = wakeData.sleepDuration.inMinutes >= wakeData.sleepGoalMinutes
        ? xpSleepGoal : 0;
    final updated = wakeData.copyWith(xp: wakeData.xp + xpBonus);
    await save(uid, updated);
    return updated;
  }

  Future<WellnessData> setSleepQuality(
      String uid, WellnessData data, SleepQuality quality) async {
    final updated = data.copyWith(sleepQuality: quality);
    await save(uid, updated);
    return updated;
  }

  // Moon phase icon based on sleep % of goal
  String moonPhaseIcon(double progress) {
    if (progress >= 0.95) return '🌕';
    if (progress >= 0.75) return '🌔';
    if (progress >= 0.5)  return '🌓';
    if (progress >= 0.25) return '🌒';
    if (progress > 0)     return '🌑';
    return '⬛';
  }
}
