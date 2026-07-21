import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'auth_service.dart';

class FinanceTransaction {
  final String id;
  final String type; // 'income' or 'expense'
  final double amount;
  final String category;
  final String date; // yyyy-MM-dd
  final String monthKey; // yyyy-MM
  final String note;

  FinanceTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    required this.monthKey,
    required this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'category': category,
      'date': date,
      'monthKey': monthKey,
      'note': note,
    };
  }

  factory FinanceTransaction.fromMap(Map<String, dynamic> map) {
    return FinanceTransaction(
      id: map['id'] ?? '',
      type: map['type'] ?? 'expense',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? 'Others',
      date: map['date'] ?? '',
      monthKey: map['monthKey'] ?? '',
      note: map['note'] ?? '',
    );
  }
}

class DebtItem {
  final String id;
  final String type; // 'to_receive' or 'to_pay'
  final String contactName;
  final double amount;
  final String note;
  bool isCompleted;
  final String date;

  DebtItem({
    required this.id,
    required this.type,
    required this.contactName,
    required this.amount,
    required this.note,
    required this.isCompleted,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'contactName': contactName,
      'amount': amount,
      'note': note,
      'isCompleted': isCompleted,
      'date': date,
    };
  }

  factory DebtItem.fromMap(Map<String, dynamic> map) {
    return DebtItem(
      id: map['id'] ?? '',
      type: map['type'] ?? 'to_receive',
      contactName: map['contactName'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      note: map['note'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      date: map['date'] ?? '',
    );
  }
}

class RecurringPayment {
  final String id;
  final String title;
  final double amount;
  final String category;
  bool isEnabled;

  RecurringPayment({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.isEnabled,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'isEnabled': isEnabled,
    };
  }

  factory RecurringPayment.fromMap(Map<String, dynamic> map) {
    return RecurringPayment(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? 'Bills',
      isEnabled: map['isEnabled'] ?? true,
    );
  }
}

class FinanceSummary {
  final double totalIncome;
  final double totalExpense;
  final double remainingBalance;
  final double zakatAmount;
  final double zakatPercentage;
  final double totalToReceive;
  final double totalToPay;
  final Map<String, double> categoryBreakdown;

  FinanceSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.remainingBalance,
    required this.zakatAmount,
    required this.zakatPercentage,
    required this.totalToReceive,
    required this.totalToPay,
    required this.categoryBreakdown,
  });
}

class FinanceService {
  static final FinanceService _instance = FinanceService._internal();
  factory FinanceService() => _instance;
  FinanceService._internal();

  bool get isSandboxMode => AuthService().isSandboxMode;

  static const List<String> categories = [
    'Food',
    'Travel',
    'Shopping',
    'Entertainment',
    'Bills',
    'Business',
    'Health',
    'Education',
    'Others'
  ];

  // --- Transactions Operations ---

  Future<List<FinanceTransaction>> getTransactions(String uid, String monthKey) async {
    final all = await _loadSandboxTransactions(uid);
    List<FinanceTransaction> list = all.where((t) => t.monthKey == monthKey).toList();

    if (list.isEmpty && !isSandboxMode) {
      try {
        final query = await fs.FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('finance_transactions')
            .where('monthKey', isEqualTo: monthKey)
            .get().timeout(const Duration(seconds: 2));
        list = query.docs.map((doc) => FinanceTransaction.fromMap(doc.data())).toList();
        // Cache locally
        for (final t in list) {
          await _saveSandboxTransaction(uid, t);
        }
      } catch (e) {
        try {
          final query = await fs.FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('finance_transactions')
              .where('monthKey', isEqualTo: monthKey)
              .get(const fs.GetOptions(source: fs.Source.cache));
          list = query.docs.map((doc) => FinanceTransaction.fromMap(doc.data())).toList();
        } catch (_) {}
      }
    }

    // Sort by date descending
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> addTransaction(String uid, FinanceTransaction transaction) async {
    await _saveSandboxTransaction(uid, transaction);
    if (!isSandboxMode) {
      fs.FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('finance_transactions').doc(transaction.id)
          .set(transaction.toMap())
          .catchError((e) => debugPrint('Finance tx Firebase sync error: $e'));
    }
  }

  Future<void> deleteTransaction(String uid, String id) async {
    await _deleteSandboxTransaction(uid, id);
    if (!isSandboxMode) {
      fs.FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('finance_transactions').doc(id)
          .delete()
          .catchError((e) => debugPrint('Finance tx delete Firebase sync error: $e'));
    }
  }

  // --- Debts Operations ---

  Future<List<DebtItem>> getDebts(String uid) async {
    List<DebtItem> list = await _loadSandboxDebts(uid);

    if (list.isEmpty && !isSandboxMode) {
      try {
        final query = await fs.FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('finance_debts')
            .get().timeout(const Duration(seconds: 2));
        list = query.docs.map((doc) => DebtItem.fromMap(doc.data())).toList();
        // Cache locally
        for (final d in list) {
          await _saveSandboxDebt(uid, d);
        }
      } catch (e) {
        try {
          final query = await fs.FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('finance_debts')
              .get(const fs.GetOptions(source: fs.Source.cache));
          list = query.docs.map((doc) => DebtItem.fromMap(doc.data())).toList();
        } catch (_) {}
      }
    }

    // Sort pending items first
    list.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      return b.date.compareTo(a.date);
    });

    return list;
  }

  Future<void> addDebt(String uid, DebtItem debt) async {
    await _saveSandboxDebt(uid, debt);
    if (!isSandboxMode) {
      fs.FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('finance_debts').doc(debt.id)
          .set(debt.toMap())
          .catchError((e) => debugPrint('Finance debt Firebase sync error: $e'));
    }
  }

  Future<void> toggleDebtCompleted(String uid, DebtItem debt) async {
    debt.isCompleted = !debt.isCompleted;
    await addDebt(uid, debt);
  }

  Future<void> deleteDebt(String uid, String id) async {
    await _deleteSandboxDebt(uid, id);
    if (!isSandboxMode) {
      fs.FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('finance_debts').doc(id)
          .delete()
          .catchError((e) => debugPrint('Finance debt delete Firebase sync error: $e'));
    }
  }

  // --- Recurring Payments Operations ---

  Future<List<RecurringPayment>> getRecurringPayments(String uid) async {
    List<RecurringPayment> list = await _loadSandboxRecurring(uid);

    if (list.isEmpty && !isSandboxMode) {
      try {
        final query = await fs.FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('finance_recurring')
            .get().timeout(const Duration(seconds: 2));
        list = query.docs.map((doc) => RecurringPayment.fromMap(doc.data())).toList();
        // Cache locally
        for (final r in list) {
          await _saveSandboxRecurring(uid, r);
        }
      } catch (e) {
        try {
          final query = await fs.FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('finance_recurring')
              .get(const fs.GetOptions(source: fs.Source.cache));
          list = query.docs.map((doc) => RecurringPayment.fromMap(doc.data())).toList();
        } catch (_) {}
      }
    }

    return list;
  }

  Future<void> addRecurringPayment(String uid, RecurringPayment payment) async {
    await _saveSandboxRecurring(uid, payment);
    if (!isSandboxMode) {
      fs.FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('finance_recurring').doc(payment.id)
          .set(payment.toMap())
          .catchError((e) => debugPrint('Finance recurring Firebase sync error: $e'));
    }
  }

  Future<void> toggleRecurringEnabled(String uid, RecurringPayment payment) async {
    payment.isEnabled = !payment.isEnabled;
    await addRecurringPayment(uid, payment);
  }

  Future<void> deleteRecurringPayment(String uid, String id) async {
    await _deleteSandboxRecurring(uid, id);
    if (!isSandboxMode) {
      fs.FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('finance_recurring').doc(id)
          .delete()
          .catchError((e) => debugPrint('Finance recurring delete Firebase sync error: $e'));
    }
  }

  // --- Monthly Summary & Zakat Calculations ---

  Future<FinanceSummary> getMonthlySummary(String uid, String monthKey, {double zakatPercentage = 2.5}) async {
    final transactions = await getTransactions(uid, monthKey);
    final debts = await getDebts(uid);
    final recurring = await getRecurringPayments(uid);

    double totalIncome = 0.0;
    double totalExpense = 0.0;
    final Map<String, double> categoryBreakdown = {};

    for (final t in transactions) {
      if (t.type == 'income') {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
        categoryBreakdown[t.category] = (categoryBreakdown[t.category] ?? 0.0) + t.amount;
      }
    }

    // Factor in enabled recurring payments for the current month summary if not logged manually
    for (final r in recurring) {
      if (r.isEnabled) {
        // Only add if not already logged as transaction with same title
        final exists = transactions.any((t) => t.note.toLowerCase().contains(r.title.toLowerCase()));
        if (!exists) {
          totalExpense += r.amount;
          categoryBreakdown[r.category] = (categoryBreakdown[r.category] ?? 0.0) + r.amount;
        }
      }
    }

    double totalToReceive = 0.0;
    double totalToPay = 0.0;

    for (final d in debts) {
      if (!d.isCompleted) {
        if (d.type == 'to_receive') {
          totalToReceive += d.amount;
        } else {
          totalToPay += d.amount;
        }
      }
    }

    final remainingBalance = totalIncome - totalExpense;
    final zakatAmount = totalIncome > 0 ? totalIncome * (zakatPercentage / 100.0) : 0.0;

    return FinanceSummary(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      remainingBalance: remainingBalance,
      zakatAmount: zakatAmount,
      zakatPercentage: zakatPercentage,
      totalToReceive: totalToReceive,
      totalToPay: totalToPay,
      categoryBreakdown: categoryBreakdown,
    );
  }

  // --- Sandbox local file storage implementations ---

  Future<List<FinanceTransaction>> _loadSandboxTransactions(String uid) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alina_sandbox_finance_trans_$uid.json');
      if (await file.exists()) {
        final List<dynamic> jsonList = jsonDecode(await file.readAsString()) as List<dynamic>;
        return jsonList.map((m) => FinanceTransaction.fromMap(m as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading sandbox transactions: $e');
    }
    return [];
  }

  Future<void> _saveSandboxTransaction(String uid, FinanceTransaction t) async {
    final list = await _loadSandboxTransactions(uid);
    final idx = list.indexWhere((item) => item.id == t.id);
    if (idx != -1) {
      list[idx] = t;
    } else {
      list.add(t);
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alina_sandbox_finance_trans_$uid.json');
      await file.writeAsString(jsonEncode(list.map((item) => item.toMap()).toList()));
    } catch (e) {
      debugPrint('Error saving sandbox transaction: $e');
    }
  }

  Future<void> _deleteSandboxTransaction(String uid, String id) async {
    final list = await _loadSandboxTransactions(uid);
    list.removeWhere((t) => t.id == id);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alina_sandbox_finance_trans_$uid.json');
      await file.writeAsString(jsonEncode(list.map((item) => item.toMap()).toList()));
    } catch (e) {
      debugPrint('Error deleting sandbox transaction: $e');
    }
  }

  Future<List<DebtItem>> _loadSandboxDebts(String uid) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alina_sandbox_finance_debts_$uid.json');
      if (await file.exists()) {
        final List<dynamic> jsonList = jsonDecode(await file.readAsString()) as List<dynamic>;
        return jsonList.map((m) => DebtItem.fromMap(m as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading sandbox debts: $e');
    }
    return [];
  }

  Future<void> _saveSandboxDebt(String uid, DebtItem d) async {
    final list = await _loadSandboxDebts(uid);
    final idx = list.indexWhere((item) => item.id == d.id);
    if (idx != -1) {
      list[idx] = d;
    } else {
      list.add(d);
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alina_sandbox_finance_debts_$uid.json');
      await file.writeAsString(jsonEncode(list.map((item) => item.toMap()).toList()));
    } catch (e) {
      debugPrint('Error saving sandbox debt: $e');
    }
  }

  Future<void> _deleteSandboxDebt(String uid, String id) async {
    final list = await _loadSandboxDebts(uid);
    list.removeWhere((d) => d.id == id);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alina_sandbox_finance_debts_$uid.json');
      await file.writeAsString(jsonEncode(list.map((item) => item.toMap()).toList()));
    } catch (e) {
      debugPrint('Error deleting sandbox debt: $e');
    }
  }

  Future<List<RecurringPayment>> _loadSandboxRecurring(String uid) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alina_sandbox_finance_recurring_$uid.json');
      if (await file.exists()) {
        final List<dynamic> jsonList = jsonDecode(await file.readAsString()) as List<dynamic>;
        return jsonList.map((m) => RecurringPayment.fromMap(m as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading sandbox recurring: $e');
    }
    return [];
  }

  Future<void> _saveSandboxRecurring(String uid, RecurringPayment r) async {
    final list = await _loadSandboxRecurring(uid);
    final idx = list.indexWhere((item) => item.id == r.id);
    if (idx != -1) {
      list[idx] = r;
    } else {
      list.add(r);
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alina_sandbox_finance_recurring_$uid.json');
      await file.writeAsString(jsonEncode(list.map((item) => item.toMap()).toList()));
    } catch (e) {
      debugPrint('Error saving sandbox recurring: $e');
    }
  }

  Future<void> _deleteSandboxRecurring(String uid, String id) async {
    final list = await _loadSandboxRecurring(uid);
    list.removeWhere((r) => r.id == id);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/alina_sandbox_finance_recurring_$uid.json');
      await file.writeAsString(jsonEncode(list.map((item) => item.toMap()).toList()));
    } catch (e) {
      debugPrint('Error deleting sandbox recurring: $e');
    }
  }
}
