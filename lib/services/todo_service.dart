import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'auth_service.dart';

class TodoItem {
  final String id;
  final String title;
  final String category;
  final String priority;
  final bool isCompleted;
  final String? dueDate; // 'YYYY-MM-DD' or null
  final String createdAt;

  const TodoItem({
    required this.id,
    required this.title,
    this.category = 'Personal',
    this.priority = 'Medium',
    this.isCompleted = false,
    this.dueDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'priority': priority,
        'isCompleted': isCompleted,
        'dueDate': dueDate,
        'createdAt': createdAt,
      };

  factory TodoItem.fromMap(Map<String, dynamic> m) => TodoItem(
        id: m['id'] ?? '',
        title: m['title'] ?? '',
        category: m['category'] ?? 'Personal',
        priority: m['priority'] ?? 'Medium',
        isCompleted: m['isCompleted'] ?? false,
        dueDate: m['dueDate'],
        createdAt: m['createdAt'] ?? '',
      );

  TodoItem copyWith({
    String? title,
    String? category,
    String? priority,
    bool? isCompleted,
    String? dueDate,
  }) =>
      TodoItem(
        id: id,
        title: title ?? this.title,
        category: category ?? this.category,
        priority: priority ?? this.priority,
        isCompleted: isCompleted ?? this.isCompleted,
        dueDate: dueDate ?? this.dueDate,
        createdAt: createdAt,
      );
}

class TodoService {
  static final TodoService _instance = TodoService._internal();
  factory TodoService() => _instance;
  TodoService._internal();

  bool get isSandboxMode => AuthService().isSandboxMode;

  static const List<String> categories = ['Personal', 'Work', 'Spiritual', 'Health', 'Study', 'Other'];
  static const List<String> priorities = ['High', 'Medium', 'Low'];

  // ─── Firestore helpers ────────────────────────────────────────────
  Future<List<TodoItem>> getTodos(String uid) async {
    try {
      if (!isSandboxMode) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('todos')
            .orderBy('createdAt', descending: true)
            .get();
        return snap.docs.map((d) => TodoItem.fromMap(d.data())).toList();
      } else {
        return await _sandboxGetTodos(uid);
      }
    } catch (e) {
      debugPrint('TodoService getTodos error: $e');
      return [];
    }
  }

  Future<void> addTodo(String uid, TodoItem item) async {
    try {
      if (!isSandboxMode) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('todos')
            .doc(item.id)
            .set(item.toMap());
      } else {
        await _sandboxSaveTodo(uid, item);
      }
    } catch (e) {
      debugPrint('TodoService addTodo error: $e');
    }
  }

  Future<void> toggleTodo(String uid, TodoItem item) async {
    final updated = item.copyWith(isCompleted: !item.isCompleted);
    await addTodo(uid, updated);
  }

  Future<void> deleteTodo(String uid, String id) async {
    try {
      if (!isSandboxMode) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('todos')
            .doc(id)
            .delete();
      } else {
        await _sandboxDeleteTodo(uid, id);
      }
    } catch (e) {
      debugPrint('TodoService deleteTodo error: $e');
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
        return raw.map((e) => TodoItem.fromMap(e as Map<String, dynamic>)).toList();
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
    await file.writeAsString(jsonEncode(todos.map((t) => t.toMap()).toList()));
  }

  Future<void> _sandboxDeleteTodo(String uid, String id) async {
    final todos = await _sandboxGetTodos(uid);
    todos.removeWhere((t) => t.id == id);
    final file = await _sandboxFile(uid);
    await file.writeAsString(jsonEncode(todos.map((t) => t.toMap()).toList()));
  }
}
