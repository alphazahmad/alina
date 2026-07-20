import 'package:flutter/material.dart';
import '../services/finance_service.dart';

enum FinanceEntryType { transaction, debt, recurring }

class AddTransactionSheet extends StatefulWidget {
  final String uid;
  final FinanceEntryType initialEntryType;
  final VoidCallback onSaved;

  const AddTransactionSheet({
    super.key,
    required this.uid,
    this.initialEntryType = FinanceEntryType.transaction,
    required this.onSaved,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _financeService = FinanceService();

  late FinanceEntryType _entryType;
  
  // Transaction fields
  String _transType = 'expense'; // 'income' or 'expense'
  final _transAmountController = TextEditingController();
  String _transCategory = 'Food';
  DateTime _transDate = DateTime.now();
  final _transNoteController = TextEditingController();

  // Debt fields
  String _debtType = 'to_receive'; // 'to_receive' or 'to_pay'
  final _debtNameController = TextEditingController();
  final _debtAmountController = TextEditingController();
  final _debtNoteController = TextEditingController();

  // Recurring fields
  final _recurringTitleController = TextEditingController();
  final _recurringAmountController = TextEditingController();
  String _recurringCategory = 'Bills';

  @override
  void initState() {
    super.initState();
    _entryType = widget.initialEntryType;
  }

  @override
  void dispose() {
    _transAmountController.dispose();
    _transNoteController.dispose();
    _debtNameController.dispose();
    _debtAmountController.dispose();
    _debtNoteController.dispose();
    _recurringTitleController.dispose();
    _recurringAmountController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    final now = DateTime.now();

    if (_entryType == FinanceEntryType.transaction) {
      final amount = double.tryParse(_transAmountController.text.trim()) ?? 0.0;
      if (amount <= 0) return;

      final dateStr = '${_transDate.year}-${_transDate.month.toString().padLeft(2, '0')}-${_transDate.day.toString().padLeft(2, '0')}';
      final monthKey = '${_transDate.year}-${_transDate.month.toString().padLeft(2, '0')}';
      final newId = now.millisecondsSinceEpoch.toString();

      final t = FinanceTransaction(
        id: newId,
        type: _transType,
        amount: amount,
        category: _transCategory,
        date: dateStr,
        monthKey: monthKey,
        note: _transNoteController.text.trim(),
      );

      await _financeService.addTransaction(widget.uid, t);
    } else if (_entryType == FinanceEntryType.debt) {
      final amount = double.tryParse(_debtAmountController.text.trim()) ?? 0.0;
      final contact = _debtNameController.text.trim();
      if (amount <= 0 || contact.isEmpty) return;

      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final newId = now.millisecondsSinceEpoch.toString();

      final d = DebtItem(
        id: newId,
        type: _debtType,
        contactName: contact,
        amount: amount,
        note: _debtNoteController.text.trim(),
        isCompleted: false,
        date: dateStr,
      );

      await _financeService.addDebt(widget.uid, d);
    } else if (_entryType == FinanceEntryType.recurring) {
      final amount = double.tryParse(_recurringAmountController.text.trim()) ?? 0.0;
      final title = _recurringTitleController.text.trim();
      if (amount <= 0 || title.isEmpty) return;

      final newId = now.millisecondsSinceEpoch.toString();

      final r = RecurringPayment(
        id: newId,
        title: title,
        amount: amount,
        category: _recurringCategory,
        isEnabled: true,
      );

      await _financeService.addRecurringPayment(widget.uid, r);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
    widget.onSaved();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _transDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1016) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Header & Entry Type Segment
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Financial Record',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Entry Selector Tabs
          SegmentedButton<FinanceEntryType>(
            segments: const [
              ButtonSegment(
                value: FinanceEntryType.transaction,
                label: Text('Transaction', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.receipt_long, size: 14),
              ),
              ButtonSegment(
                value: FinanceEntryType.debt,
                label: Text('Debt / Credit', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.handshake, size: 14),
              ),
              ButtonSegment(
                value: FinanceEntryType.recurring,
                label: Text('Recurring', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.autorenew, size: 14),
              ),
            ],
            selected: {_entryType},
            onSelectionChanged: (set) {
              setState(() {
                _entryType = set.first;
              });
            },
          ),
          const Divider(height: 24),
          
          Expanded(
            child: SingleChildScrollView(
              child: _buildFormContent(theme, isDark),
            ),
          ),
          
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Save Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent(ThemeData theme, bool isDark) {
    if (_entryType == FinanceEntryType.transaction) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Income vs Expense Segment
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'expense',
                label: Text('Expense 🔴'),
              ),
              ButtonSegment(
                value: 'income',
                label: Text('Income 🟢'),
              ),
            ],
            selected: {_transType},
            onSelectionChanged: (set) {
              setState(() {
                _transType = set.first;
              });
            },
          ),
          const SizedBox(height: 16),

          // Amount
          TextField(
            controller: _transAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (₹ / \$)',
              prefixIcon: Icon(Icons.attach_money),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Category Dropdown
          DropdownButtonFormField<String>(
            initialValue: _transCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category),
              border: OutlineInputBorder(),
            ),
            dropdownColor: isDark ? const Color(0xFF1E1016) : Colors.white,
            items: FinanceService.categories.map((c) {
              return DropdownMenuItem(value: c, child: Text(c));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _transCategory = val);
            },
          ),
          const SizedBox(height: 16),

          // Date Selection
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date',
                prefixIcon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(),
              ),
              child: Text(
                '${_transDate.day}/${_transDate.month}/${_transDate.year}',
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Note
          TextField(
            controller: _transNoteController,
            decoration: const InputDecoration(
              labelText: 'Note (Optional)',
              prefixIcon: Icon(Icons.note),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );
    } else if (_entryType == FinanceEntryType.debt) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'to_receive',
                label: Text('To Receive (Lene Hain) 🟢'),
              ),
              ButtonSegment(
                value: 'to_pay',
                label: Text('To Pay (Dene Hain) 🔴'),
              ),
            ],
            selected: {_debtType},
            onSelectionChanged: (set) {
              setState(() {
                _debtType = set.first;
              });
            },
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _debtNameController,
            decoration: const InputDecoration(
              labelText: 'Person / Contact Name',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _debtAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (₹ / \$)',
              prefixIcon: Icon(Icons.attach_money),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _debtNoteController,
            decoration: const InputDecoration(
              labelText: 'Note / Reason (Optional)',
              prefixIcon: Icon(Icons.note),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _recurringTitleController,
            decoration: const InputDecoration(
              labelText: 'Bill / Subscription Title (e.g. Rent)',
              prefixIcon: Icon(Icons.receipt),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _recurringAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monthly Amount',
              prefixIcon: Icon(Icons.attach_money),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            initialValue: _recurringCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category),
              border: OutlineInputBorder(),
            ),
            dropdownColor: isDark ? const Color(0xFF1E1016) : Colors.white,
            items: FinanceService.categories.map((c) {
              return DropdownMenuItem(value: c, child: Text(c));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _recurringCategory = val);
            },
          ),
        ],
      );
    }
  }
}
