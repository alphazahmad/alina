import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/wellness_service.dart';
import '../theme/app_theme.dart';

// ════════════════════════════════════════════════════════════════════════════
//  WELLNESS HUB — Shell
// ════════════════════════════════════════════════════════════════════════════
class WellnessHub extends StatefulWidget {
  final String uid;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChangeTheme;
  final String email;

  final int initialTab;

  const WellnessHub({
    super.key,
    required this.uid,
    required this.themeMode,
    required this.onChangeTheme,
    required this.email,
    this.initialTab = 0,
  });

  @override
  State<WellnessHub> createState() => _WellnessHubState();
}

class _WellnessHubState extends State<WellnessHub> {
  final _service = WellnessService();
  WellnessData _data = const WellnessData();
  bool _loading = true;
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _load();
  }

  Future<void> _load() async {
    final d = await _service.load(widget.uid);
    if (mounted) setState(() { _data = d; _loading = false; });
  }

  void _update(WellnessData d) {
    if (mounted) setState(() => _data = d);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return Column(
      children: [
        // ── XP Panel ───────────────────────────────────────────────
        _XpPanel(data: _data, isDark: isDark),

        // ── Sub-tab switcher ────────────────────────────────────────
        _SubTabBar(selected: _tab, onSelect: (i) => setState(() => _tab = i), isDark: isDark),

        // ── Content ─────────────────────────────────────────────────
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              WaterTrackerView(uid: widget.uid, data: _data, onUpdate: _update),
              FoodTrackerView(uid: widget.uid, data: _data, onUpdate: _update),
              SleepTrackerView(uid: widget.uid, data: _data, onUpdate: _update),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  XP PANEL
// ════════════════════════════════════════════════════════════════════════════
class _XpPanel extends StatelessWidget {
  final WellnessData data;
  final bool isDark;

  const _XpPanel({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A0A14), const Color(0xFF0D0D20)]
              : [const Color(0xFFFFF0F6), const Color(0xFFEEF0FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
        boxShadow: AppShadows.softCard(isDark),
      ),
      child: Row(
        children: [
          // XP ring
          _XpRing(progress: data.xpProgress, level: data.level, isDark: isDark),
          const SizedBox(width: 16),

          // XP + Streak info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Level ${data.level}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    // Streak badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF9500)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            '${data.streak} day${data.streak == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // XP bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: data.xpProgress),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.1),
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                      minHeight: 7,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.xpInCurrentLevel} / 100 XP  ·  ${data.xp} total',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 10),
                // Weekly dots
                Row(
                  children: List.generate(7, (i) {
                    final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                    final active = i < data.weeklyActivity.length &&
                        data.weeklyActivity[i];
                    return Expanded(
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.15),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 8,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// XP progress ring using CustomPainter
class _XpRing extends StatelessWidget {
  final double progress;
  final int level;
  final bool isDark;

  const _XpRing({required this.progress, required this.level, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68, height: 68,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => CustomPaint(
          painter: _RingPainter(progress: v, isDark: isDark),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('⚡', style: TextStyle(fontSize: 14)),
                Text(
                  '$level',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _RingPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    final strokeW = 5.0;

    // Background ring
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..color = AppColors.primary.withValues(alpha: 0.12);
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final grad = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + 2 * math.pi,
      colors: [AppColors.primary, AppColors.primaryLight],
      stops: [progress, progress],
    );
    final fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..shader = grad.createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, fgPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ════════════════════════════════════════════════════════════════════════════
//  SUB-TAB BAR
// ════════════════════════════════════════════════════════════════════════════
class _SubTabBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  final bool isDark;

  const _SubTabBar({required this.selected, required this.onSelect, required this.isDark});

  static const _tabs = [
    ('💧', 'Water'),
    ('🍽️', 'Food'),
    ('😴', 'Sleep'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141414) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final (emoji, label) = _tabs[i];
            final isSelected = selected == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(colors: AppColors.primaryGradient)
                        : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isSelected
                        ? AppShadows.glowCard(AppColors.primary, isDark: isDark)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white54 : Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  WATER TRACKER
// ════════════════════════════════════════════════════════════════════════════
class WaterTrackerView extends StatefulWidget {
  final String uid;
  final WellnessData data;
  final ValueChanged<WellnessData> onUpdate;

  const WaterTrackerView({super.key, required this.uid, required this.data, required this.onUpdate});

  @override
  State<WaterTrackerView> createState() => _WaterTrackerViewState();
}

class _WaterTrackerViewState extends State<WaterTrackerView>
    with TickerProviderStateMixin {
  final _service = WellnessService();
  late AnimationController _splashCtrl;
  late AnimationController _celebCtrl;
  int? _lastFilled;
  bool _showCelebration = false;

  @override
  void initState() {
    super.initState();
    _splashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _celebCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
  }

  @override
  void dispose() {
    _splashCtrl.dispose();
    _celebCtrl.dispose();
    super.dispose();
  }

  Future<void> _addGlass() async {
    final d = await _service.addGlass(widget.uid, widget.data);
    widget.onUpdate(d);
    HapticFeedback.lightImpact();
    setState(() => _lastFilled = d.waterGlasses - 1);
    _splashCtrl.forward(from: 0);
    if (d.waterGlasses >= d.waterGoal) {
      setState(() => _showCelebration = true);
      _celebCtrl.forward(from: 0);
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _removeGlass() async {
    if (widget.data.waterGlasses <= 0) return;
    final d = await _service.removeGlass(widget.uid, widget.data);
    widget.onUpdate(d);
    HapticFeedback.selectionClick();
    setState(() => _showCelebration = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = widget.data;
    final filled = data.waterGlasses;
    final goal = data.waterGoal;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        // ── Goal progress row ─────────────────────────────────────
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$filled / $goal glasses',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '${(filled * 250)} ml of ${goal * 250} ml',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
            const Spacer(),
            // Minus button
            _RoundBtn(
              icon: Icons.remove_rounded,
              color: Colors.blueGrey,
              onTap: _removeGlass,
            ),
            const SizedBox(width: 10),
            // Plus button
            _RoundBtn(
              icon: Icons.add_rounded,
              color: const Color(0xFF29B6F6),
              onTap: _addGlass,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Celebration banner ────────────────────────────────────
        if (_showCelebration)
          _CelebrationBanner(
            emoji: '🎉',
            message: "Today's Hydration Complete!",
            color: const Color(0xFF29B6F6),
            isDark: isDark,
          ),

        const SizedBox(height: 8),

        // ── Glass grid ────────────────────────────────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: goal,
          itemBuilder: (_, i) {
            final isFilled = i < filled;
            final isJustFilled = i == _lastFilled;

            return GestureDetector(
              onTap: isFilled ? _removeGlass : _addGlass,
              child: AnimatedBuilder(
                animation: _splashCtrl,
                builder: (_, _) {
                  final splash = isJustFilled
                      ? math.sin(_splashCtrl.value * math.pi)
                      : 0.0;
                  return Transform.scale(
                    scale: 1.0 + splash * 0.08,
                    child: _GlassWidget(
                      filled: isFilled,
                      isDark: isDark,
                      sparkle: _showCelebration && isFilled,
                    ),
                  );
                },
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // ── Daily tip ─────────────────────────────────────────────
        _TipCard(
          emoji: '💡',
          text: 'Drinking a glass of water before meals can boost metabolism by up to 30%.',
          color: const Color(0xFF29B6F6),
          isDark: isDark,
        ),
      ],
    );
  }
}

// Glass Widget
class _GlassWidget extends StatelessWidget {
  final bool filled;
  final bool isDark;
  final bool sparkle;

  const _GlassWidget({required this.filled, required this.isDark, required this.sparkle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: filled
              ? const Color(0xFF29B6F6).withValues(alpha: 0.6)
              : (isDark ? Colors.white12 : Colors.grey.shade200),
          width: 1.5,
        ),
        color: isDark ? const Color(0xFF0D1117) : Colors.white,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Fill
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                height: filled ? 80 : 0,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF81D4FA), Color(0xFF0288D1)],
                  ),
                ),
              ),
            ),
            // Sparkle overlay
            if (sparkle)
              Positioned.fill(
                child: Center(
                  child: Text('✨', style: TextStyle(fontSize: 18)),
                ),
              ),
            // Glass icon
            Center(
              child: Icon(
                filled ? Icons.local_drink_rounded : Icons.local_drink_outlined,
                size: 28,
                color: filled ? Colors.white : (isDark ? Colors.white24 : Colors.grey.shade300),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  FOOD TRACKER
// ════════════════════════════════════════════════════════════════════════════
class FoodTrackerView extends StatefulWidget {
  final String uid;
  final WellnessData data;
  final ValueChanged<WellnessData> onUpdate;

  const FoodTrackerView({super.key, required this.uid, required this.data, required this.onUpdate});

  @override
  State<FoodTrackerView> createState() => _FoodTrackerViewState();
}

class _FoodTrackerViewState extends State<FoodTrackerView> {
  final _service = WellnessService();

  bool get _allDone =>
      WellnessService.meals.every((m) =>
          (widget.data.mealStates[m.key] ?? MealState.pending) == MealState.eaten);

  Future<void> _tap(MealDef meal) async {
    final curr = widget.data.mealStates[meal.key] ?? MealState.pending;
    // pending → eaten → pending (toggle)
    final next = curr == MealState.eaten ? MealState.pending : MealState.eaten;
    final d = await _service.setMealState(widget.uid, widget.data, meal.key, next);
    widget.onUpdate(d);
    HapticFeedback.lightImpact();
  }

  Future<void> _longPress(MealDef meal) async {
    final curr = widget.data.mealStates[meal.key] ?? MealState.pending;
    final next = curr == MealState.missed ? MealState.pending : MealState.missed;
    final d = await _service.setMealState(widget.uid, widget.data, meal.key, next);
    widget.onUpdate(d);
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        // Celebration
        if (_allDone)
          _CelebrationBanner(
            emoji: '🌟',
            message: 'Perfect Nutrition Day!',
            color: const Color(0xFF66BB6A),
            isDark: isDark,
          ),

        // Meal timeline strip
        _MealTimeline(data: widget.data, isDark: isDark),
        const SizedBox(height: 16),

        // Meal cards
        ...WellnessService.meals.map((meal) {
          final state = widget.data.mealStates[meal.key] ?? MealState.pending;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MealCard(
              meal: meal,
              state: state,
              isDark: isDark,
              onTap: () => _tap(meal),
              onLongPress: () => _longPress(meal),
            ),
          );
        }),

        const SizedBox(height: 8),
        _TipCard(
          emoji: '💡',
          text: 'Tap a meal to mark it eaten ✔, long-press to mark as missed ✖.',
          color: const Color(0xFF66BB6A),
          isDark: isDark,
        ),
      ],
    );
  }
}

class _MealTimeline extends StatelessWidget {
  final WellnessData data;
  final bool isDark;

  const _MealTimeline({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: WellnessService.meals.map((meal) {
          final state = data.mealStates[meal.key] ?? MealState.pending;
          final color = state == MealState.eaten
              ? Colors.green
              : state == MealState.missed
                  ? Colors.red
                  : Colors.orange;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(meal.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Text(meal.name,
                  style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
              Text(meal.time,
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final MealDef meal;
  final MealState state;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MealCard({
    required this.meal,
    required this.state,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isEaten  = state == MealState.eaten;
    final isMissed = state == MealState.missed;

    Color borderColor;
    Color bgColor;
    String statusEmoji;
    Color statusColor;

    if (isEaten) {
      borderColor = Colors.green.withValues(alpha: 0.3);
      bgColor = Colors.green.withValues(alpha: 0.05);
      statusEmoji = '✔';
      statusColor = Colors.green;
    } else if (isMissed) {
      borderColor = Colors.red.withValues(alpha: 0.3);
      bgColor = Colors.red.withValues(alpha: 0.05);
      statusEmoji = '✖';
      statusColor = Colors.red;
    } else {
      borderColor =
          (isDark ? Colors.white12 : Colors.grey.shade200);
      bgColor = isDark ? const Color(0xFF141414) : Colors.white;
      statusEmoji = '';
      statusColor = Colors.transparent;
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: AppShadows.softCard(isDark),
        ),
        child: Row(
          children: [
            // Meal emoji with grayscale when eaten
            ColorFiltered(
              colorFilter: isEaten
                  ? const ColorFilter.matrix([
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0,      0,      0,      1, 0,
                    ])
                  : const ColorFilter.mode(Colors.transparent, BlendMode.color),
              child: Text(meal.emoji, style: const TextStyle(fontSize: 36)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(meal.icon, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      Text(
                        meal.time,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // State badge
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: state == MealState.pending
                    ? Colors.transparent
                    : statusColor.withValues(alpha: 0.15),
                border: Border.all(
                  color: state == MealState.pending
                      ? (isDark ? Colors.white24 : Colors.grey.shade300)
                      : statusColor,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: statusEmoji.isEmpty
                    ? null
                    : Text(
                        statusEmoji,
                        style: TextStyle(
                            fontSize: 14,
                            color: statusColor,
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SLEEP TRACKER
// ════════════════════════════════════════════════════════════════════════════
class SleepTrackerView extends StatefulWidget {
  final String uid;
  final WellnessData data;
  final ValueChanged<WellnessData> onUpdate;

  const SleepTrackerView({super.key, required this.uid, required this.data, required this.onUpdate});

  @override
  State<SleepTrackerView> createState() => _SleepTrackerViewState();
}

class _SleepTrackerViewState extends State<SleepTrackerView>
    with TickerProviderStateMixin {
  final _service = WellnessService();
  late AnimationController _sceneCtrl;
  late AnimationController _starCtrl;

  @override
  void initState() {
    super.initState();
    _sceneCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _starCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    if (widget.data.isSleeping) _sceneCtrl.value = 1.0;
  }

  @override
  void dispose() {
    _sceneCtrl.dispose();
    _starCtrl.dispose();
    super.dispose();
  }

  Future<void> _goToSleep() async {
    final d = await _service.goToSleep(widget.uid, widget.data);
    widget.onUpdate(d);
    _sceneCtrl.forward();
    HapticFeedback.mediumImpact();
  }

  Future<void> _wakeUp() async {
    final d = await _service.wakeUp(widget.uid, widget.data);
    widget.onUpdate(d);
    _sceneCtrl.reverse();
    HapticFeedback.mediumImpact();
  }

  Future<void> _setQuality(SleepQuality q) async {
    final d = await _service.setSleepQuality(widget.uid, widget.data, q);
    widget.onUpdate(d);
  }

  String _formatTime(String? iso) {
    if (iso == null) return '--:--';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h  = dt.hour.toString().padLeft(2, '0');
      final m  = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '--:--';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data   = widget.data;
    final isSleeping = data.isSleeping;
    final hasWoken   = data.wakeTime != null && !isSleeping;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        // ── Day/Night Scene ──────────────────────────────────────
        _SleepScene(sceneCtrl: _sceneCtrl, starCtrl: _starCtrl, isDark: isDark),
        const SizedBox(height: 20),

        // ── Moon Arc Progress ────────────────────────────────────
        _MoonArcCard(data: data, isDark: isDark),
        const SizedBox(height: 16),

        // ── Action Button ─────────────────────────────────────────
        if (!isSleeping && !hasWoken)
          _GradientBtn(
            label: '🌙  Going to Sleep',
            colors: [const Color(0xFF3949AB), const Color(0xFF1565C0)],
            onTap: _goToSleep,
          )
        else if (isSleeping)
          _GradientBtn(
            label: '☀️  I Woke Up',
            colors: [const Color(0xFFFF9800), const Color(0xFFF57C00)],
            onTap: _wakeUp,
          ),

        // ── Sleep Quality (after waking) ─────────────────────────
        if (hasWoken) ...[
          const SizedBox(height: 16),
          Text(
            'How did you sleep?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: SleepQuality.values
                .where((q) => q != SleepQuality.none)
                .map((q) {
              final isSelected = data.sleepQuality == q;
              return GestureDetector(
                onTap: () => _setQuality(q),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF3949AB).withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF3949AB)
                          : (isDark ? Colors.white24 : Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(q.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(q.label,
                          style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : Colors.black54)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        // ── Sleep Timeline ────────────────────────────────────────
        if (data.bedtime != null) ...[
          const SizedBox(height: 20),
          _SleepTimeline(data: data, formatTime: _formatTime, isDark: isDark),
        ],

        // ── Weekly Moon View ──────────────────────────────────────
        const SizedBox(height: 20),
        _WeeklyMoonView(data: data, isDark: isDark),

        const SizedBox(height: 16),
        _TipCard(
          emoji: '💡',
          text: 'Consistent sleep schedules improve sleep quality by syncing your body clock.',
          color: const Color(0xFF3949AB),
          isDark: isDark,
        ),
      ],
    );
  }
}

// Sleep scene animation
class _SleepScene extends StatelessWidget {
  final AnimationController sceneCtrl;
  final AnimationController starCtrl;
  final bool isDark;

  const _SleepScene({required this.sceneCtrl, required this.starCtrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([sceneCtrl, starCtrl]),
      builder: (_, _) {
        final night = sceneCtrl.value;
        final twinkle = starCtrl.value;

        final skyColor = Color.lerp(
          const Color(0xFFFFF9C4), // dawn yellow
          const Color(0xFF1A237E), // deep night blue
          night,
        )!;

        return Container(
          height: 160,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [skyColor, skyColor.withValues(alpha: 0.4)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              // Stars (night only)
              if (night > 0.3)
                Positioned(
                  top: 16, right: 30,
                  child: Opacity(
                    opacity: ((night - 0.3) * 1.4).clamp(0.0, 1.0) *
                        (0.5 + 0.5 * twinkle),
                    child: const Text('✨', style: TextStyle(fontSize: 14)),
                  ),
                ),
              if (night > 0.5)
                Positioned(
                  top: 28, right: 70,
                  child: Opacity(
                    opacity: ((night - 0.5) * 2).clamp(0.0, 1.0) *
                        (0.5 + 0.5 * (1 - twinkle)),
                    child: const Text('⭐', style: TextStyle(fontSize: 10)),
                  ),
                ),
              if (night > 0.4)
                Positioned(
                  top: 10, left: 60,
                  child: Opacity(
                    opacity: ((night - 0.4) * 1.7).clamp(0.0, 1.0) * twinkle,
                    child: const Text('✨', style: TextStyle(fontSize: 10)),
                  ),
                ),

              // Sun / Moon
              Positioned(
                top: 20, left: 24,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: night > 0.5
                      ? const Text('🌙', style: TextStyle(fontSize: 40), key: ValueKey('moon'))
                      : const Text('☀️', style: TextStyle(fontSize: 40), key: ValueKey('sun')),
                ),
              ),

              // Bed
              const Positioned(
                bottom: 16, left: 0, right: 0,
                child: Center(
                  child: Text('🛏️', style: TextStyle(fontSize: 42)),
                ),
              ),

              // Person
              Positioned(
                bottom: 20, left: 0, right: 0,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: night > 0.5
                        ? const Text('😴', style: TextStyle(fontSize: 22), key: ValueKey('sleeping'))
                        : const Text('🧍', style: TextStyle(fontSize: 22), key: ValueKey('awake')),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Moon arc progress card
class _MoonArcCard extends StatelessWidget {
  final WellnessData data;
  final bool isDark;

  const _MoonArcCard({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final progress = data.sleepProgress;
    final goalH = data.sleepGoalMinutes ~/ 60;
    final goalM = data.sleepGoalMinutes % 60;
    final goalLabel = goalM > 0 ? '${goalH}h ${goalM}m' : '${goalH}h';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF3949AB).withValues(alpha: 0.2)),
        boxShadow: AppShadows.softCard(isDark),
      ),
      child: Row(
        children: [
          // Moon arc ring
          SizedBox(
            width: 80, height: 80,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => CustomPaint(
                painter: _MoonArcPainter(progress: v),
                child: const Center(
                  child: Text('🌙', style: TextStyle(fontSize: 24)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.sleepDurationLabel,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'of $goalLabel goal · ${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFF3949AB).withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF5C6BC0)),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoonArcPainter extends CustomPainter {
  final double progress;
  _MoonArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = const Color(0xFF3949AB).withValues(alpha: 0.12);
    canvas.drawCircle(center, radius, bg);

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [Color(0xFF5C6BC0), Color(0xFF9FA8DA)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(_MoonArcPainter old) => old.progress != progress;
}

class _SleepTimeline extends StatelessWidget {
  final WellnessData data;
  final String Function(String?) formatTime;
  final bool isDark;

  const _SleepTimeline({required this.data, required this.formatTime, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3949AB).withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _TimelineItem('🌙', 'Bedtime', formatTime(data.bedtime)),
          _timelineDivider(),
          _TimelineItem('💤', 'Sleep', formatTime(data.bedtime)),
          _timelineDivider(),
          _TimelineItem('☀️', 'Wake Up', formatTime(data.wakeTime)),
          _timelineDivider(),
          _TimelineItem('😴', 'Total', data.sleepDurationLabel),
        ],
      ),
    );
  }

  Widget _timelineDivider() => Container(width: 1, height: 36, color: Colors.grey.shade300);
}

class _TimelineItem extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _TimelineItem(this.emoji, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        Text(value,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5C6BC0))),
      ],
    );
  }
}

class _WeeklyMoonView extends StatelessWidget {
  final WellnessData data;
  final bool isDark;

  const _WeeklyMoonView({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final service = WellnessService();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3949AB).withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Sleep',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (i) {
              final active = i < data.weeklyActivity.length && data.weeklyActivity[i];
              final moon = service.moonPhaseIcon(active ? 1.0 : 0.0);
              final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              return Column(
                children: [
                  Text(moon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(days[i],
                      style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black38)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoundBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _GradientBtn extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  const _GradientBtn({required this.label, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.3),
              blurRadius: 16, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _CelebrationBanner extends StatelessWidget {
  final String emoji;
  final String message;
  final Color color;
  final bool isDark;

  const _CelebrationBanner({
    required this.emoji,
    required this.message,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String emoji;
  final String text;
  final Color color;
  final bool isDark;

  const _TipCard({required this.emoji, required this.text, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}
