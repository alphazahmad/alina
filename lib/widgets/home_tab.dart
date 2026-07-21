import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/namaz_dashboard.dart';
import '../services/todo_service.dart';
import '../services/calendar_service.dart';
import '../services/finance_service.dart';
import '../screens/wellness_hub.dart';
import 'zikr_dashboard.dart';
import 'routine_dashboard.dart';
import 'finance_dashboard.dart';

class HomeTab extends StatefulWidget {
  final String uid;
  final int relationshipLevel;
  final int lovePoints;
  final String alinaMood;
  final Map<String, Map<String, dynamic>> last7DaysRecords;
  final bool isLoading;
  final VoidCallback onRefresh;
  final ValueChanged<int>? onTabSelected;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChangeTheme;
  final String email;

  const HomeTab({
    super.key,
    required this.uid,
    required this.relationshipLevel,
    required this.lovePoints,
    required this.alinaMood,
    required this.last7DaysRecords,
    required this.isLoading,
    required this.onRefresh,
    this.onTabSelected,
    required this.themeMode,
    required this.onChangeTheme,
    required this.email,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _todoService = TodoService();
  final _calendarService = CalendarService();
  final _financeService = FinanceService();

  bool _isLoadingExtra = true;
  List<TodoItem> _top5Tasks = [];
  List<CalendarEvent> _upcomingEvents = [];
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  double _remainingBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadExtraData();
  }

  Future<void> _loadExtraData() async {
    if (!mounted) return;
    setState(() => _isLoadingExtra = true);

    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      // 1. Fetch Todos
      final allTodos = await _todoService.getTodos(widget.uid);
      final pending = allTodos.where((t) => !t.isCompleted).toList();
      pending.sort((a, b) {
        final pA = a.priority == 'High' ? 3 : (a.priority == 'Medium' ? 2 : 1);
        final pB = b.priority == 'High' ? 3 : (b.priority == 'Medium' ? 2 : 1);
        if (pB != pA) return pB.compareTo(pA);
        return b.createdAt.compareTo(a.createdAt);
      });
      _top5Tasks = pending.take(5).toList();

      // 2. Fetch Events
      final userEvents = await _calendarService.getUserEvents(widget.uid);
      final holidays = _calendarService.getNationalHolidays(now.year) +
                       _calendarService.getNationalHolidays(now.year + 1);
      final islamic = _calendarService.getIslamicEvents(now.year) +
                      _calendarService.getIslamicEvents(now.year + 1);
      final combined = [...userEvents, ...holidays, ...islamic];
      final upcoming = combined.where((e) => e.date.compareTo(todayStr) >= 0).toList();
      upcoming.sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        return a.time.compareTo(b.time);
      });
      _upcomingEvents = upcoming.take(5).toList();

      // 3. Fetch Finance
      final summary = await _financeService.getMonthlySummary(widget.uid, monthKey);
      _totalIncome = summary.totalIncome;
      _totalExpense = summary.totalExpense;
      _remainingBalance = summary.remainingBalance;

    } catch (e) {
      debugPrint('Error loading home extra data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingExtra = false);
      }
    }
  }

  Future<void> _toggleTask(TodoItem task) async {
    await _todoService.toggleTodo(widget.uid, task);
    _loadExtraData();
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // The nav bar is inside the parent Column — no extra clearance needed.
    // Just add a comfortable 16px below the last card.
    const bottomPad = 16.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadExtraData();
          widget.onRefresh();
        },
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, bottomPad),
          children: [
            // ─── Alina Hero Card ─────────────────────────────────────
            _buildAlinaHeroCard(isDark),
            const SizedBox(height: 16),

            // ─── Quick Access Features Grid ──────────────────────────
            _buildFeaturesGrid(context, isDark),
            const SizedBox(height: 16),

            // ─── Finance Bento Row (Income + Expense) ────────────────
            _isLoadingExtra
                ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildFinanceMiniCard(
                            'Income',
                            '₹${_totalIncome.toStringAsFixed(0)}',
                            Icons.trending_up_rounded,
                            AppColors.incomeGradient,
                            isDark,
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _buildFinanceMiniCard(
                            'Expense',
                            '₹${_totalExpense.toStringAsFixed(0)}',
                            Icons.trending_down_rounded,
                            AppColors.expenseGradient,
                            isDark,
                          )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // ─── Net Balance Full-Width ────────────────────
                      _buildBalanceCard(isDark),
                    ],
                  ),
            const SizedBox(height: 12),

            // ─── Namaz Dashboard ─────────────────────────────────────
            BentoCard(
              padding: const EdgeInsets.all(4),
              child: NamazDashboard(uid: widget.uid, isEmbedded: true),
            ),
            const SizedBox(height: 12),

            // ─── Tasks + Events Bento Row ────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildTasksBentoCard(isDark)),
                const SizedBox(width: 12),
                Expanded(child: _buildEventsBentoCard(isDark)),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      // FAB removed — Chat is now a dedicated navigation tab
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  ALINA HERO CARD — Gradient Mesh Background
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildAlinaHeroCard(bool isDark) {
    final lvl = widget.relationshipLevel;
    final pts = widget.lovePoints;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? AppColors.heroGradientDark : AppColors.heroGradientLight,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.glowCard(AppColors.primary, isDark: isDark),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2.5),
                  image: const DecorationImage(
                    image: AssetImage('assets/alina.png'),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: AppColors.primaryGradient),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1A0A10) : Colors.white,
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.favorite, color: Colors.white, size: 10),
              ),
            ],
          ),
          const SizedBox(width: 18),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Alina', style: AppTextStyles.heading(isDark).copyWith(fontSize: 20)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: AppColors.primaryGradient),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Lvl $lvl',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.alinaMood,
                  style: AppTextStyles.caption(isDark).copyWith(fontSize: 13),
                ),
                const SizedBox(height: 10),
                // Love points bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (pts % 100) / 100,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$pts pts',
                      style: AppTextStyles.caption(isDark).copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  FINANCE MINI CARDS — Income & Expense
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildFinanceMiniCard(String label, String value, IconData icon, List<Color> gradient, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppDecoration.bentoCard(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient.map((c) => c.withValues(alpha: 0.15)).toList()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: gradient.first, size: 18),
          ),
          const SizedBox(height: 12),
          Text(label, style: AppTextStyles.caption(isDark)),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.metricSmall(isDark)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  NET BALANCE CARD — Full-Width Accent
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildBalanceCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0A1A2A), const Color(0xFF0A0A14)]
              : [const Color(0xFFE8F4FD), const Color(0xFFF0F8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.balance.withValues(alpha: 0.15)),
        boxShadow: AppShadows.subtle(isDark),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.balance.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.balance, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Net Balance', style: AppTextStyles.caption(isDark)),
              const SizedBox(height: 2),
              Text(
                '₹${_remainingBalance.toStringAsFixed(0)}',
                style: AppTextStyles.metric(isDark).copyWith(color: AppColors.balance),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'This Month',
            style: AppTextStyles.caption(isDark).copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  TASKS BENTO CARD
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildTasksBentoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecoration.bentoCard(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.expense.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.checklist_rounded, color: AppColors.expense, size: 14),
              ),
              const SizedBox(width: 8),
              Text('Tasks', style: AppTextStyles.label(isDark).copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingExtra)
            const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ))
          else if (_top5Tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 24)),
                    const SizedBox(height: 6),
                    Text('All done!', style: AppTextStyles.caption(isDark)),
                  ],
                ),
              ),
            )
          else
            ...List.generate(_top5Tasks.length, (i) {
              final task = _top5Tasks[i];
              Color pColor = AppColors.income;
              if (task.priority == 'High') pColor = AppColors.warning;
              if (task.priority == 'Medium') pColor = AppColors.expense;

              return Padding(
                padding: EdgeInsets.only(bottom: i < _top5Tasks.length - 1 ? 10 : 0),
                child: GestureDetector(
                  onTap: () => _toggleTask(task),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: pColor.withValues(alpha: 0.5), width: 1.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: AppTextStyles.body(isDark).copyWith(fontSize: 12, fontWeight: FontWeight.w500),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: pColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                task.priority,
                                style: TextStyle(fontSize: 8, color: pColor, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  EVENTS BENTO CARD
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildEventsBentoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecoration.bentoCard(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.islamic.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_today_rounded, color: AppColors.islamic, size: 14),
              ),
              const SizedBox(width: 8),
              Text('Events', style: AppTextStyles.label(isDark).copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingExtra)
            const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ))
          else if (_upcomingEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    const Text('📅', style: TextStyle(fontSize: 24)),
                    const SizedBox(height: 6),
                    Text('No events', style: AppTextStyles.caption(isDark)),
                  ],
                ),
              ),
            )
          else
            ...List.generate(_upcomingEvents.length, (i) {
              final event = _upcomingEvents[i];

              String prefix = '📅';
              if (event.type == 'holiday') prefix = '🎉';
              if (event.type == 'islamic') prefix = '🕌';
              if (event.type == 'finance') prefix = '💰';

              return Padding(
                padding: EdgeInsets.only(bottom: i < _upcomingEvents.length - 1 ? 10 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prefix, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: AppTextStyles.body(isDark).copyWith(fontSize: 12, fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            event.date,
                            style: AppTextStyles.caption(isDark).copyWith(fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FEATURES GRID & SUB-PAGE WRAPPER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFeaturesGrid(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'QUICK ACCESS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            _buildGridItem(
              context, '💬', 'Alina Chat', const Color(0xFFF52670),
              () => widget.onTabSelected?.call(1), isDark,
            ),
            _buildGridItem(
              context, '📋', 'Tasks', const Color(0xFFFF9500),
              () => widget.onTabSelected?.call(2), isDark,
            ),
            _buildGridItem(
              context, '🕌', 'Namaz', const Color(0xFF30D5C8),
              () => widget.onTabSelected?.call(3), isDark,
            ),
            _buildGridItem(
              context, '📿', 'Zikr', const Color(0xFF007AFF),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubPageWrapper(
                    title: 'Zikr Dashboard',
                    child: ZikrDashboard(uid: widget.uid),
                  ),
                ),
              ), isDark,
            ),
            _buildGridItem(
              context, '🕒', 'Routine', const Color(0xFF8E44AD),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubPageWrapper(
                    title: 'Routine Builder',
                    child: RoutineDashboard(uid: widget.uid),
                  ),
                ),
              ), isDark,
            ),
            _buildGridItem(
              context, '💵', 'Finance', const Color(0xFF34C759),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubPageWrapper(
                    title: 'Finance Hub',
                    child: FinanceDashboard(uid: widget.uid),
                  ),
                ),
              ), isDark,
            ),
            _buildGridItem(
              context, '💧', 'Water', const Color(0xFF29B6F6),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubPageWrapper(
                    title: 'Water Tracker',
                    child: WellnessHub(
                      uid: widget.uid,
                      themeMode: widget.themeMode,
                      onChangeTheme: widget.onChangeTheme,
                      email: widget.email,
                      initialTab: 0,
                    ),
                  ),
                ),
              ), isDark,
            ),
            _buildGridItem(
              context, '🍏', 'Food Log', const Color(0xFF66BB6A),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubPageWrapper(
                    title: 'Food Tracker',
                    child: WellnessHub(
                      uid: widget.uid,
                      themeMode: widget.themeMode,
                      onChangeTheme: widget.onChangeTheme,
                      email: widget.email,
                      initialTab: 1,
                    ),
                  ),
                ),
              ), isDark,
            ),
            _buildGridItem(
              context, '🌙', 'Sleep Sync', const Color(0xFF3949AB),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubPageWrapper(
                    title: 'Sleep Sync',
                    child: WellnessHub(
                      uid: widget.uid,
                      themeMode: widget.themeMode,
                      onChangeTheme: widget.onChangeTheme,
                      email: widget.email,
                      initialTab: 2,
                    ),
                  ),
                ),
              ), isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridItem(
    BuildContext context,
    String emoji,
    String title,
    Color color,
    VoidCallback onTap,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubPageWrapper extends StatelessWidget {
  final Widget child;
  final String title;

  const SubPageWrapper({super.key, required this.child, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: child,
    );
  }
}
