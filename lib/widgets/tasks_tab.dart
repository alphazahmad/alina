import 'package:flutter/material.dart';
import '../services/todo_service.dart';
import '../theme/app_theme.dart';
import '../widgets/calendar_dashboard.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  TASKS TAB — outer shell (To-Do / Calendar pill switcher)
// ═══════════════════════════════════════════════════════════════════════════════
class TasksTab extends StatefulWidget {
  final String uid;
  const TasksTab({super.key, required this.uid});

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  int _innerIndex = 0; // 0 = To-Do, 1 = Calendar

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // ─── Pill Tab Switcher ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121212) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                _buildPillTab(0, Icons.checklist_rounded, 'To-Do', theme, isDark),
                _buildPillTab(
                    1, Icons.calendar_month_rounded, 'Calendar', theme, isDark),
              ],
            ),
          ),
        ),

        // ─── Content ───────────────────────────────────────────────
        Expanded(
          child: IndexedStack(
            index: _innerIndex,
            children: [
              _TodoListView(uid: widget.uid),
              CalendarDashboard(uid: widget.uid),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPillTab(
      int index, IconData icon, String label, ThemeData theme, bool isDark) {
    final isSelected = _innerIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _innerIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white54 : Colors.grey.shade600)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
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
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TO-DO LIST VIEW  (phases + subtasks)
// ═══════════════════════════════════════════════════════════════════════════════
class _TodoListView extends StatefulWidget {
  final String uid;
  const _TodoListView({required this.uid});

  @override
  State<_TodoListView> createState() => _TodoListViewState();
}

class _TodoListViewState extends State<_TodoListView> {
  final _todoService = TodoService();
  List<TodoItem> _todos = [];
  bool _isLoading = true;
  String _activeFilter = 'All';

  /// Which task cards are expanded (show subtasks)
  final Set<String> _expandedIds = {};
  /// Which phase sections are collapsed
  final Set<String> _collapsedPhases = {};

  static const _filters = [
    'All', 'Pending', 'Done', 'Work', 'Personal', 'Spiritual', 'Health',
  ];

  // Phase colour palette
  static const Map<String, Color> _phaseColors = {
    'Planning':    Color(0xFF6C63FF),
    'In Progress': Color(0xFFFF9800),
    'Review':      Color(0xFF00BCD4),
    'Done':        Color(0xFF4CAF50),
    'On Hold':     Color(0xFF9E9E9E),
  };

  Color _phaseColor(String phase) =>
      _phaseColors[phase] ?? AppColors.primary;

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final todos = await _todoService.getTodos(widget.uid);
    if (mounted) setState(() { _todos = todos; _isLoading = false; });
  }

  List<TodoItem> get _filteredTodos {
    if (_activeFilter == 'All') return _todos;
    if (_activeFilter == 'Pending') return _todos.where((t) => !t.isCompleted).toList();
    if (_activeFilter == 'Done') return _todos.where((t) => t.isCompleted).toList();
    return _todos.where((t) => t.category == _activeFilter).toList();
  }

  /// Group todos by phase. Tasks with no phase → key = '' → shown as "Other".
  Map<String, List<TodoItem>> get _grouped {
    final map = <String, List<TodoItem>>{};
    for (final t in _filteredTodos) {
      final key = t.phase.isEmpty ? '' : t.phase;
      (map[key] ??= []).add(t);
    }
    return map;
  }

  /// Ordered phase keys: preset phases first (in order), then custom, then '' last.
  List<String> _orderedPhaseKeys(Map<String, List<TodoItem>> grouped) {
    final keys = grouped.keys.toSet();
    final ordered = <String>[];
    for (final p in TodoService.presetPhases) {
      if (keys.contains(p)) ordered.add(p);
    }
    for (final k in keys) {
      if (k.isNotEmpty && !TodoService.presetPhases.contains(k)) {
        ordered.add(k);
      }
    }
    if (keys.contains('')) ordered.add('');
    return ordered;
  }

  // ─────────────────────────────────────────────────────────────────
  //  ADD / EDIT BOTTOM SHEET
  // ─────────────────────────────────────────────────────────────────
  Future<void> _showAddSheet([TodoItem? existing]) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final customPhaseCtrl = TextEditingController();

    String category = existing?.category ?? 'Personal';
    String priority = existing?.priority ?? 'Medium';
    String? dueDate = existing?.dueDate;
    String phase = existing?.phase ?? '';
    final subtasks = List<SubTask>.from(existing?.subtasks ?? []);
    bool showCustomPhase = false;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setLocal) {
          final bg = isDark ? const Color(0xFF0F0F0F) : Colors.white;
          final cardBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8);

          // ── Add-subtask mini field ──────────────────────────────
          final subCtrl = TextEditingController();

          void addSubTask() {
            final t = subCtrl.text.trim();
            if (t.isEmpty) return;
            setLocal(() {
              subtasks.add(SubTask(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: t,
              ));
              subCtrl.clear();
            });
          }

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx2).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 44, height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: AppColors.primaryGradient),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.task_alt_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        existing != null ? 'Edit Task' : 'New Task',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Task title ──────────────────────────────────
                  _sectionLabel('Task Title', isDark),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    autofocus: existing == null,
                    style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: _inputDeco(
                      label: 'What needs to be done?',
                      icon: Icons.edit_rounded,
                      isDark: isDark,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Phase selector ──────────────────────────────
                  _sectionLabel('Phase', isDark),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // "No Phase" chip
                        _phaseChip(
                          label: 'No Phase',
                          color: Colors.grey,
                          isSelected: phase.isEmpty,
                          onTap: () => setLocal(() {
                            phase = '';
                            showCustomPhase = false;
                          }),
                        ),
                        const SizedBox(width: 8),
                        // Preset phase chips
                        ...TodoService.presetPhases.map((p) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _phaseChip(
                            label: p,
                            color: _phaseColor(p),
                            isSelected: phase == p,
                            onTap: () => setLocal(() {
                              phase = p;
                              showCustomPhase = false;
                            }),
                          ),
                        )),
                        // Custom phase chip
                        _phaseChip(
                          label: '+ Custom',
                          color: AppColors.primary,
                          isSelected: showCustomPhase,
                          onTap: () =>
                              setLocal(() => showCustomPhase = !showCustomPhase),
                        ),
                      ],
                    ),
                  ),
                  if (showCustomPhase) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: customPhaseCtrl,
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87),
                      decoration: _inputDeco(
                        label: 'Custom phase name',
                        icon: Icons.label_outline_rounded,
                        isDark: isDark,
                        theme: theme,
                      ),
                      onChanged: (v) => setLocal(() => phase = v.trim()),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // ── Category + Priority ─────────────────────────
                  _sectionLabel('Details', isDark),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: _inputDeco(
                            label: 'Category',
                            icon: Icons.category_outlined,
                            isDark: isDark,
                            theme: theme,
                          ),
                          dropdownColor: bg,
                          items: TodoService.categories
                              .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c,
                                      style: const TextStyle(fontSize: 12))))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setLocal(() => category = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: priority,
                          decoration: _inputDeco(
                            label: 'Priority',
                            icon: Icons.flag_outlined,
                            isDark: isDark,
                            theme: theme,
                          ),
                          dropdownColor: bg,
                          items: TodoService.priorities
                              .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p,
                                      style: const TextStyle(fontSize: 12))))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setLocal(() => priority = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Due date ────────────────────────────────────
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx2,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setLocal(() => dueDate =
                            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Text(
                            dueDate ?? 'Set due date (optional)',
                            style: TextStyle(
                                color: dueDate != null
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : Colors.grey,
                                fontSize: 13),
                          ),
                          const Spacer(),
                          if (dueDate != null)
                            GestureDetector(
                              onTap: () => setLocal(() => dueDate = null),
                              child: const Icon(Icons.close,
                                  size: 16, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Subtasks ────────────────────────────────────
                  Row(
                    children: [
                      _sectionLabel('Subtasks', isDark),
                      const Spacer(),
                      if (subtasks.isNotEmpty)
                        Text(
                          '${subtasks.where((s) => s.isCompleted).length}/${subtasks.length} done',
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Existing subtasks
                  if (subtasks.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: subtasks.asMap().entries.map((e) {
                          final i = e.key;
                          final s = e.value;
                          return Padding(
                            padding: EdgeInsets.only(
                              left: 12, right: 8, top: 6,
                              bottom: i == subtasks.length - 1 ? 6 : 0,
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => setLocal(() {
                                    subtasks[i] = s.copyWith(
                                        isCompleted: !s.isCompleted);
                                  }),
                                  child: Container(
                                    width: 20, height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: s.isCompleted
                                          ? Colors.green.withValues(alpha: 0.15)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: s.isCompleted
                                            ? Colors.green
                                            : Colors.grey.shade400,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: s.isCompleted
                                        ? const Icon(Icons.check,
                                            size: 12, color: Colors.green)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    s.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: s.isCompleted
                                          ? Colors.grey
                                          : (isDark
                                              ? Colors.white70
                                              : Colors.black87),
                                      decoration: s.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 15, color: Colors.grey),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () =>
                                      setLocal(() => subtasks.removeAt(i)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Add subtask row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: subCtrl,
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black87),
                          decoration: _inputDeco(
                            label: 'Add a subtask…',
                            icon: Icons.subdirectory_arrow_right_rounded,
                            isDark: isDark,
                            theme: theme,
                          ),
                          onSubmitted: (_) {
                            addSubTask();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: addSubTask,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: AppColors.primaryGradient),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── Notes ───────────────────────────────────────
                  _sectionLabel('Notes (optional)', isDark),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87),
                    decoration: _inputDeco(
                      label: 'Add any notes or context…',
                      icon: Icons.notes_rounded,
                      isDark: isDark,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Save button ─────────────────────────────────
                  GestureDetector(
                    onTap: () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      final item = TodoItem(
                        id: existing?.id ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        title: title,
                        category: category,
                        priority: priority,
                        isCompleted: existing?.isCompleted ?? false,
                        dueDate: dueDate,
                        createdAt: existing?.createdAt ??
                            DateTime.now().toIso8601String(),
                        phase: phase,
                        subtasks: subtasks,
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      );
                      Navigator.pop(ctx2);
                      await _todoService.addTodo(widget.uid, item);
                      _loadTodos();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: AppColors.primaryGradient),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppShadows.glowCard(AppColors.primary,
                            isDark: isDark),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Save Task',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pending = _todos.where((t) => !t.isCompleted).length;
    final done = _todos.where((t) => t.isCompleted).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Summary strip ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _miniStat('$pending', 'Pending', Colors.orange, isDark),
                const SizedBox(width: 10),
                _miniStat('$done', 'Done', Colors.green, isDark),
                const Spacer(),
                if (_todos.isNotEmpty)
                  Text(
                    '${(done / _todos.length * 100).toStringAsFixed(0)}% complete',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),

          // ── Filter chips ──────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _filters.map((f) {
                final isSelected = _activeFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label:
                        Text(f, style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    selectedColor: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.primary
                        .withValues(alpha: 0.05),
                    labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : theme.colorScheme.primary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal),
                    onSelected: (v) {
                      if (v) setState(() => _activeFilter = f);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // ── Task list ─────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTodos.isEmpty
                    ? _emptyState(isDark)
                    : _buildGroupedList(theme, isDark),
          ),
        ],
      ),
      floatingActionButton: _buildFab(theme, isDark),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  GROUPED LIST
  // ─────────────────────────────────────────────────────────────────
  Widget _buildGroupedList(ThemeData theme, bool isDark) {
    final grouped = _grouped;
    final keys = _orderedPhaseKeys(grouped);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final key = keys[i];
        final label = key.isEmpty ? 'Other' : key;
        final items = grouped[key]!;
        final isCollapsed = _collapsedPhases.contains(key);
        final color = key.isEmpty ? Colors.grey : _phaseColor(key);

        final totalSubs = items.fold<int>(0, (s, t) => s + t.subtaskTotal);
        final doneSubs = items.fold<int>(0, (s, t) => s + t.subtaskDone);
        final doneCount = items.where((t) => t.isCompleted).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Phase header
            GestureDetector(
              onTap: () => setState(() {
                if (isCollapsed) {
                  _collapsedPhases.remove(key);
                } else {
                  _collapsedPhases.add(key);
                }
              }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8, top: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border(
                    left: BorderSide(color: color, width: 3.5),
                  ),
                ),
                child: Row(
                  children: [
                    // Phase dot + name
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: color),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Task count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$doneCount/${items.length}',
                        style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (totalSubs > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '· $doneSubs/$totalSubs subtasks',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                    const Spacer(),
                    Icon(
                      isCollapsed
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      size: 18,
                      color: color.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),

            // Task cards
            if (!isCollapsed)
              ...items.map((todo) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildTodoCard(todo, theme, isDark),
                  )),

            const SizedBox(height: 4),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  TASK CARD
  // ─────────────────────────────────────────────────────────────────
  Widget _buildTodoCard(TodoItem todo, ThemeData theme, bool isDark) {
    Color priorityColor = Colors.orange;
    if (todo.priority == 'High') priorityColor = Colors.red;
    if (todo.priority == 'Low') priorityColor = Colors.green;

    final isExpanded = _expandedIds.contains(todo.id);
    final phaseColor =
        todo.phase.isEmpty ? Colors.grey : _phaseColor(todo.phase);

    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) async {
        await _todoService.deleteTodo(widget.uid, todo.id);
        _loadTodos();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131313) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: todo.isCompleted
                ? Colors.grey.withValues(alpha: 0.15)
                : priorityColor.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : Colors.grey)
                  .withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Main row
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() {
                if (isExpanded) {
                  _expandedIds.remove(todo.id);
                } else {
                  _expandedIds.add(todo.id);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checkbox
                    GestureDetector(
                      onTap: () async {
                        await _todoService.toggleTodo(widget.uid, todo);
                        _loadTodos();
                      },
                      child: Container(
                        width: 24, height: 24,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: todo.isCompleted
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.transparent,
                          border: Border.all(
                              color: todo.isCompleted
                                  ? Colors.green
                                  : Colors.grey.shade400,
                              width: 1.5),
                        ),
                        child: todo.isCompleted
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.green)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            todo.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: todo.isCompleted
                                  ? Colors.grey
                                  : (isDark ? Colors.white : Colors.black87),
                              decoration: todo.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Tags row
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: [
                              // Priority badge
                              _badge(todo.priority, priorityColor),
                              // Category badge
                              _badge(todo.category, Colors.blueGrey),
                              // Phase badge
                              if (todo.phase.isNotEmpty)
                                _badge(todo.phase, phaseColor),
                              // Due date
                              if (todo.dueDate != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today_outlined,
                                        size: 10,
                                        color: Colors.grey.shade500),
                                    const SizedBox(width: 3),
                                    Text(todo.dueDate!,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey)),
                                  ],
                                ),
                            ],
                          ),

                          // Subtask progress bar
                          if (todo.subtaskTotal > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: todo.subtaskProgress,
                                      backgroundColor: priorityColor
                                          .withValues(alpha: 0.1),
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              priorityColor),
                                      minHeight: 4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${todo.subtaskDone}/${todo.subtaskTotal}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],

                          // Notes preview
                          if (todo.notes != null &&
                              todo.notes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              todo.notes!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Action icons
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              size: 16, color: Colors.grey),
                          onPressed: () => _showAddSheet(todo),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        if (todo.subtaskTotal > 0) ...[
                          const SizedBox(height: 8),
                          Icon(
                            isExpanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 18,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Inline subtask checklist (expanded) ─────────────
            if (isExpanded && todo.subtaskTotal > 0)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: todo.subtasks.map((sub) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () async {
                          await _todoService.toggleSubTask(
                              widget.uid, todo, sub.id);
                          _loadTodos();
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 18, height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: sub.isCompleted
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: sub.isCompleted
                                      ? Colors.green
                                      : Colors.grey.shade400,
                                  width: 1.5,
                                ),
                              ),
                              child: sub.isCompleted
                                  ? const Icon(Icons.check,
                                      size: 11, color: Colors.green)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                sub.title,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: sub.isCompleted
                                      ? Colors.grey
                                      : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                  decoration: sub.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────────
  Widget _buildFab(ThemeData theme, bool isDark) {
    return GestureDetector(
      onTap: _showAddSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: AppColors.primaryGradient),
          borderRadius: BorderRadius.circular(20),
          boxShadow:
              AppShadows.glowCard(AppColors.primary, isDark: isDark),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_task_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Add Task',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String value, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text('$value $label',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  Widget _emptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist_rounded,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No tasks here!',
              style:
                  TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          const SizedBox(height: 6),
          Text('Tap + to add a task',
              style:
                  TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 9, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _phaseChip({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
    );
  }

  InputDecoration _inputDeco({
    required String label,
    required IconData icon,
    required bool isDark,
    required ThemeData theme,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
    );
  }
}
