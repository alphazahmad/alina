import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'auth_service.dart';

// ─── SubTask ────────────────────────────────────────────────────────────────
class SubTask {
  final String id;
  final String title;
  final bool isCompleted;

  const SubTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
      };

  factory SubTask.fromMap(Map<String, dynamic> m) => SubTask(
        id: m['id'] ?? '',
        title: m['title'] ?? '',
        isCompleted: m['isCompleted'] ?? false,
      );

  SubTask copyWith({String? title, bool? isCompleted}) => SubTask(
        id: id,
        title: title ?? this.title,
        isCompleted: isCompleted ?? this.isCompleted,
      );
}

// ─── TodoItem ────────────────────────────────────────────────────────────────
class TodoItem {
  final String id;
  final String title;
  final String category;
  final String priority;
  final bool isCompleted;
  final String? dueDate;   // 'YYYY-MM-DD' or null
  final String createdAt;

  // ── New fields (backward-compatible) ──────────────────────────────
  final String phase;           // e.g. "Planning", "Build", "" = none
  final List<SubTask> subtasks; // inline checklist
  final String? notes;          // optional freeform note

  const TodoItem({
    required this.id,
    required this.title,
    this.category = 'Personal',
    this.priority = 'Medium',
    this.isCompleted = false,
    this.dueDate,
    required this.createdAt,
    this.phase = '',
    this.subtasks = const [],
    this.notes,
  });

  // ── Computed helpers ───────────────────────────────────────────────
  int get subtaskTotal => subtasks.length;
  int get subtaskDone  => subtasks.where((s) => s.isCompleted).length;
  double get subtaskProgress =>
      subtaskTotal == 0 ? 0.0 : subtaskDone / subtaskTotal;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'priority': priority,
        'isCompleted': isCompleted,
        'dueDate': dueDate,
        'createdAt': createdAt,
        'phase': phase,
        'subtasks': subtasks.map((s) => s.toMap()).toList(),
        'notes': notes,
      };

  factory TodoItem.fromMap(Map<String, dynamic> m) {
    final rawSubs = m['subtasks'];
    final subtasks = rawSubs is List
        ? rawSubs
            .whereType<Map<String, dynamic>>()
            .map(SubTask.fromMap)
            .toList()
        : <SubTask>[];
    return TodoItem(
      id: m['id'] ?? '',
      title: m['title'] ?? '',
      category: m['category'] ?? 'Personal',
      priority: m['priority'] ?? 'Medium',
      isCompleted: m['isCompleted'] ?? false,
      dueDate: m['dueDate'],
      createdAt: m['createdAt'] ?? '',
      phase: m['phase'] ?? '',
      subtasks: subtasks,
      notes: m['notes'],
    );
  }

  TodoItem copyWith({
    String? title,
    String? category,
    String? priority,
    bool? isCompleted,
    String? dueDate,
    String? phase,
    List<SubTask>? subtasks,
    String? notes,
    bool clearDueDate = false,
    bool clearNotes = false,
  }) =>
      TodoItem(
        id: id,
        title: title ?? this.title,
        category: category ?? this.category,
        priority: priority ?? this.priority,
        isCompleted: isCompleted ?? this.isCompleted,
        dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
        createdAt: createdAt,
        phase: phase ?? this.phase,
        subtasks: subtasks ?? this.subtasks,
        notes: clearNotes ? null : (notes ?? this.notes),
      );
}

// ─── TodoService ─────────────────────────────────────────────────────────────
class TodoService {
  static final TodoService _instance = TodoService._internal();
  factory TodoService() => _instance;
  TodoService._internal();

  bool get isSandboxMode => AuthService().isSandboxMode;

  static const List<String> categories = [
    'Personal', 'Work', 'Spiritual', 'Health', 'Study', 'Other'
  ];
  static const List<String> priorities = ['High', 'Medium', 'Low'];

  /// Preset phase names — user can also type a custom phase.
  static const List<String> presetPhases = [
    'Planning', 'In Progress', 'Review', 'Done', 'On Hold',
  ];

  // ─── Public CRUD ─────────────────────────────────────────────────
  Future<List<TodoItem>> getTodos(String uid) async {
    try {
      List<TodoItem> list = await _sandboxGetTodos(uid);

      if (list.isEmpty && !isSandboxMode) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('todos')
            .orderBy('createdAt', descending: true)
            .get();
        list = snap.docs.map((d) => TodoItem.fromMap(d.data())).toList();
        for (final item in list) {
          await _sandboxSaveTodo(uid, item);
        }
      }
      return list;
    } catch (e) {
      debugPrint('TodoService getTodos error: $e');
      return [];
    }
  }

  Future<void> addTodo(String uid, TodoItem item) async {
    await _sandboxSaveTodo(uid, item);
    if (!isSandboxMode) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('todos')
          .doc(item.id)
          .set(item.toMap())
          .catchError((e) => debugPrint('Todo Firebase sync error: $e'));
    }
  }

  Future<void> toggleTodo(String uid, TodoItem item) async {
    final updated = item.copyWith(isCompleted: !item.isCompleted);
    await addTodo(uid, updated);
  }

  Future<void> toggleSubTask(String uid, TodoItem item, String subId) async {
    final subs = item.subtasks.map((s) {
      if (s.id == subId) return s.copyWith(isCompleted: !s.isCompleted);
      return s;
    }).toList();
    await addTodo(uid, item.copyWith(subtasks: subs));
  }

  Future<void> deleteTodo(String uid, String id) async {
    await _sandboxDeleteTodo(uid, id);
    if (!isSandboxMode) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('todos')
          .doc(id)
          .delete()
          .catchError((e) => debugPrint('Todo delete Firebase sync error: $e'));
    }
  }

  // ─── Sandbox helpers ──────────────────────────────────────────────
  Future<File> _sandboxFile(String uid) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/alina_todos_$uid.json');
  }

  Future<List<TodoItem>> _sandboxGetTodos(String uid) async {
    try {
      final file = await _sandboxFile(uid);
      if (await file.exists()) {
        final List<dynamic> raw = jsonDecode(await file.readAsString());
        return raw
            .map((e) => TodoItem.fromMap(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Sandbox getTodos error: $e');
    }
    return [];
  }

  Future<void> _sandboxSaveTodo(String uid, TodoItem item) async {
    final todos = await _sandboxGetTodos(uid);
    final idx = todos.indexWhere((t) => t.id == item.id);
    if (idx >= 0) {
      todos[idx] = item;
    } else {
      todos.insert(0, item);
    }
    final file = await _sandboxFile(uid);
    await file.writeAsString(
        jsonEncode(todos.map((t) => t.toMap()).toList()));
  }

  Future<void> _sandboxDeleteTodo(String uid, String id) async {
    final todos = await _sandboxGetTodos(uid);
    todos.removeWhere((t) => t.id == id);
    final file = await _sandboxFile(uid);
    await file.writeAsString(
        jsonEncode(todos.map((t) => t.toMap()).toList()));
  }
}
