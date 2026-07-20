import 'package:flutter/material.dart';
import '../services/todo_service.dart';
import '../widgets/calendar_dashboard.dart';

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
              color: isDark ? const Color(0xFF1C1020) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                _buildPillTab(0, Icons.checklist_rounded, 'To-Do', theme, isDark),
                _buildPillTab(1, Icons.calendar_month_rounded, 'Calendar', theme, isDark),
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

  Widget _buildPillTab(int index, IconData icon, String label, ThemeData theme, bool isDark) {
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
                ? [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.grey.shade600)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── To-Do List View ──────────────────────────────────────────────────────
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

  final List<String> _filters = ['All', 'Pending', 'Done', 'Work', 'Personal', 'Spiritual', 'Health'];

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

  Future<void> _showAddDialog([TodoItem? existing]) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    String category = existing?.category ?? 'Personal';
    String priority = existing?.priority ?? 'Medium';
    String? dueDate = existing?.dueDate;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setLocal) => Container(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx2).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1020) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44, height: 5,
                  decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                existing != null ? 'Edit Task' : 'New Task',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Task title',
                  prefixIcon: const Icon(Icons.edit_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        prefixIcon: const Icon(Icons.category_outlined, size: 18),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      dropdownColor: isDark ? const Color(0xFF1C1020) : Colors.white,
                      items: TodoService.categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) { if (v != null) setLocal(() => category = v); },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        prefixIcon: const Icon(Icons.flag_outlined, size: 18),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      dropdownColor: isDark ? const Color(0xFF1C1020) : Colors.white,
                      items: TodoService.priorities.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) { if (v != null) setLocal(() => priority = v); },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx2,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setLocal(() => dueDate = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        dueDate ?? 'Set due date (optional)',
                        style: TextStyle(color: dueDate != null ? (isDark ? Colors.white : Colors.black87) : Colors.grey, fontSize: 13),
                      ),
                      const Spacer(),
                      if (dueDate != null)
                        GestureDetector(
                          onTap: () => setLocal(() => dueDate = null),
                          child: const Icon(Icons.close, size: 16, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) return;
                  final item = TodoItem(
                    id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    title: title,
                    category: category,
                    priority: priority,
                    isCompleted: existing?.isCompleted ?? false,
                    dueDate: dueDate,
                    createdAt: existing?.createdAt ?? DateTime.now().toIso8601String(),
                  );
                  Navigator.pop(ctx2);
                  await _todoService.addTodo(widget.uid, item);
                  _loadTodos();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Save Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filteredTodos;
    final pending = _todos.where((t) => !t.isCompleted).length;
    final done = _todos.where((t) => t.isCompleted).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary strip
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _miniStat('$pending', 'Pending', Colors.orange, isDark, theme),
                const SizedBox(width: 10),
                _miniStat('$done', 'Done', Colors.green, isDark, theme),
                const Spacer(),
                // Progress
                Text(
                  _todos.isEmpty ? '' : '${(done / _todos.length * 100).toStringAsFixed(0)}% complete',
                  style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _filters.map((f) {
                final isSelected = _activeFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f, style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    selectedColor: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.05),
                    labelStyle: TextStyle(color: isSelected ? Colors.white : theme.colorScheme.primary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    onSelected: (v) { if (v) setState(() => _activeFilter = f); },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.checklist, size: 52, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No tasks here!', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                            const SizedBox(height: 6),
                            Text('Tap + to add a task', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _buildTodoCard(filtered[i], theme, isDark),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _miniStat(String value, String label, Color color, bool isDark, ThemeData theme) {
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
          Text('$value $label', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildTodoCard(TodoItem todo, ThemeData theme, bool isDark) {
    Color priorityColor = Colors.orange;
    if (todo.priority == 'High') priorityColor = Colors.red;
    if (todo.priority == 'Low') priorityColor = Colors.green;

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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1020) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: todo.isCompleted ? Colors.grey.withValues(alpha: 0.2) : priorityColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            GestureDetector(
              onTap: () async {
                await _todoService.toggleTodo(widget.uid, todo);
                _loadTodos();
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: todo.isCompleted ? Colors.green.withValues(alpha: 0.15) : Colors.transparent,
                  border: Border.all(color: todo.isCompleted ? Colors.green : Colors.grey.shade400, width: 1.5),
                ),
                child: todo.isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.green)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: todo.isCompleted ? Colors.grey : (isDark ? Colors.white : Colors.black87),
                      decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(todo.priority, style: TextStyle(fontSize: 9, color: priorityColor, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                      Text(todo.category, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      if (todo.dueDate != null) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.calendar_today_outlined, size: 10, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text(todo.dueDate!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 17, color: Colors.grey),
              onPressed: () => _showAddDialog(todo),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
