import 'package:flutter/material.dart';
import '../services/finance_service.dart';
import '../screens/add_transaction_sheet.dart';

class FinanceDashboard extends StatefulWidget {
  final String uid;

  const FinanceDashboard({
    super.key,
    required this.uid,
  });

  @override
  State<FinanceDashboard> createState() => _FinanceDashboardState();
}

class _FinanceDashboardState extends State<FinanceDashboard> {
  final _financeService = FinanceService();

  String _selectedMonthKey = '';
  List<String> _availableMonths = [];

  FinanceSummary? _summary;
  List<FinanceTransaction> _transactions = [];
  List<DebtItem> _debts = [];
  List<RecurringPayment> _recurring = [];

  double _zakatPercentage = 2.5;
  int _activeSubTab = 0; // 0: Transactions, 1: Debts, 2: Recurring, 3: Analytics
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _generateMonthList();
    _loadFinanceData();
  }

  void _generateMonthList() {
    final now = DateTime.now();
    final List<String> list = [];
    for (int i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final k = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      list.add(k);
    }
    _availableMonths = list;
  }

  Future<void> _loadFinanceData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final summary = await _financeService.getMonthlySummary(widget.uid, _selectedMonthKey, zakatPercentage: _zakatPercentage);
      final trans = await _financeService.getTransactions(widget.uid, _selectedMonthKey);
      final debts = await _financeService.getDebts(widget.uid);
      final recurring = await _financeService.getRecurringPayments(widget.uid);

      if (mounted) {
        setState(() {
          _summary = summary;
          _transactions = trans;
          _debts = debts;
          _recurring = recurring;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading finance data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openAddSheet(FinanceEntryType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionSheet(
        uid: widget.uid,
        initialEntryType: type,
        onSaved: _loadFinanceData,
      ),
    );
  }

  Future<void> _toggleDebt(DebtItem debt) async {
    await _financeService.toggleDebtCompleted(widget.uid, debt);
    _loadFinanceData();
  }

  Future<void> _deleteDebt(String id) async {
    await _financeService.deleteDebt(widget.uid, id);
    _loadFinanceData();
  }

  Future<void> _toggleRecurring(RecurringPayment payment) async {
    await _financeService.toggleRecurringEnabled(widget.uid, payment);
    _loadFinanceData();
  }

  Future<void> _deleteRecurring(String id) async {
    await _financeService.deleteRecurringPayment(widget.uid, id);
    _loadFinanceData();
  }

  Future<void> _deleteTransaction(String id) async {
    await _financeService.deleteTransaction(widget.uid, id);
    _loadFinanceData();
  }

  void _showZakatPercentageDialog() {
    final controller = TextEditingController(text: _zakatPercentage.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zakat Percentage'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Zakat Rate (%)',
            suffixText: '%',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim()) ?? 2.5;
              setState(() {
                _zakatPercentage = val;
              });
              Navigator.of(context).pop();
              _loadFinanceData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatMonthLabel(String key) {
    final p = key.split('-');
    final yr = p[0];
    final moIdx = int.parse(p[1]) - 1;
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[moIdx]} $yr';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Financial Overview Block
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF22131A) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Month Dropdown Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatMonthLabel(_selectedMonthKey),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedMonthKey,
                                underline: const SizedBox(),
                                dropdownColor: isDark ? const Color(0xFF1E1016) : Colors.white,
                                icon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
                                onChanged: (newKey) {
                                  if (newKey != null) {
                                    setState(() {
                                      _selectedMonthKey = newKey;
                                    });
                                    _loadFinanceData();
                                  }
                                },
                                items: _availableMonths.map((m) {
                                  final parts = m.split('-');
                                  final mIdx = int.parse(parts[1]) - 1;
                                  final shortM = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                  return DropdownMenuItem(
                                    value: m,
                                    child: Text('${shortM[mIdx]} ${parts[0]}', style: const TextStyle(fontSize: 12)),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Balance Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: (_summary?.remainingBalance ?? 0) >= 0
                                  ? [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)]
                                  : [Colors.red.shade700, Colors.red.shade500],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Net Monthly Balance',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(_summary?.remainingBalance ?? 0) >= 0 ? "+" : ""}${(_summary?.remainingBalance ?? 0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Income & Expense Metrics
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                'Income',
                                '+${(_summary?.totalIncome ?? 0).toStringAsFixed(2)}',
                                Colors.green,
                                Icons.arrow_upward,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildMetricTile(
                                'Expenses',
                                '-${(_summary?.totalExpense ?? 0).toStringAsFixed(2)}',
                                Colors.red,
                                Icons.arrow_downward,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Main Sub-Tab Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSubTabChip(0, 'Transactions'),
                        const SizedBox(width: 8),
                        _buildSubTabChip(1, 'Debts / Credits'),
                        const SizedBox(width: 8),
                        _buildSubTabChip(2, 'Recurring Bills'),
                        const SizedBox(width: 8),
                        _buildSubTabChip(3, 'Analytics & Zakat'),
                      ],
                    ),
                  ),
                ),

                // Sub-tab View Content
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12.0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B0D13) : Colors.white.withValues(alpha: 0.6),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32.0),
                      ),
                    ),
                    child: _buildSubTabContent(),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_activeSubTab == 1) {
            _openAddSheet(FinanceEntryType.debt);
          } else if (_activeSubTab == 2) {
            _openAddSheet(FinanceEntryType.recurring);
          } else {
            _openAddSheet(FinanceEntryType.transaction);
          }
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          _activeSubTab == 1
              ? 'Add Debt'
              : _activeSubTab == 2
                  ? 'Add Recurring'
                  : 'Add Entry',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(
                  value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabChip(int index, String label) {
    final isSelected = _activeSubTab == index;
    final theme = Theme.of(context);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _activeSubTab = index;
          });
        }
      },
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.05),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : theme.colorScheme.primary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildSubTabContent() {
    if (_activeSubTab == 0) {
      return _buildTransactionsTab();
    } else if (_activeSubTab == 1) {
      return _buildDebtsTab();
    } else if (_activeSubTab == 2) {
      return _buildRecurringTab();
    } else {
      return _buildAnalyticsTab();
    }
  }

  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) {
      return const Center(
        child: Text(
          'No transactions logged for this month.\nTap + below to add an income or expense entry.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView.separated(
      itemCount: _transactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final t = _transactions[index];
        final isIncome = t.type == 'income';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C1A23) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isIncome ? Colors.green : Colors.red).withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isIncome ? Colors.green : Colors.red).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIncome ? Colors.green : Colors.red,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.note.isEmpty ? t.category : t.note,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '${t.category} • ${t.date}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                '${isIncome ? "+" : "-"}${t.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isIncome ? Colors.green : Colors.red,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                onPressed: () => _deleteTransaction(t.id),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDebtsTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Debt metrics summary header
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                'To Receive (Paise Lene)',
                (_summary?.totalToReceive ?? 0).toStringAsFixed(2),
                Colors.green,
                Icons.south_west,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                'To Pay (Paise Dene)',
                (_summary?.totalToPay ?? 0).toStringAsFixed(2),
                Colors.red,
                Icons.north_east,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Expanded(
          child: _debts.isEmpty
              ? const Center(
                  child: Text(
                    'No debt or credit items added yet.\nTap + below to add a debt entry.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  itemCount: _debts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  padding: const EdgeInsets.only(bottom: 80),
                  itemBuilder: (context, index) {
                    final d = _debts[index];
                    final isToReceive = d.type == 'to_receive';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C1A23) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: d.isCompleted
                              ? Colors.grey.withValues(alpha: 0.2)
                              : (isToReceive ? Colors.green : Colors.red).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: d.isCompleted,
                            activeColor: Colors.green,
                            onChanged: (_) => _toggleDebt(d),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.contactName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    decoration: d.isCompleted ? TextDecoration.lineThrough : null,
                                    color: d.isCompleted ? Colors.grey : null,
                                  ),
                                ),
                                Text(
                                  '${isToReceive ? "To Receive" : "To Pay"}${d.note.isNotEmpty ? " • ${d.note}" : ""}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${isToReceive ? "+" : "-"}${d.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: d.isCompleted ? Colors.grey : (isToReceive ? Colors.green : Colors.red),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                            onPressed: () => _deleteDebt(d.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecurringTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_recurring.isEmpty) {
      return const Center(
        child: Text(
          'No monthly recurring payments configured.\nTap + below to add subscriptions, rent, or EMI.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      itemCount: _recurring.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final r = _recurring[index];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C1A23) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: r.isEnabled ? theme.colorScheme.primary.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.autorenew,
                color: r.isEnabled ? theme.colorScheme.primary : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: r.isEnabled ? null : Colors.grey,
                      ),
                    ),
                    Text(
                      '${r.category} • Monthly Auto Carry',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                r.amount.toStringAsFixed(2),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: r.isEnabled ? theme.colorScheme.primary : Colors.grey,
                ),
              ),
              Switch(
                value: r.isEnabled,
                onChanged: (_) => _toggleRecurring(r),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                onPressed: () => _deleteRecurring(r.id),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final breakdown = _summary?.categoryBreakdown ?? {};
    final totalExpense = _summary?.totalExpense ?? 0.001;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Zakat Calculator Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C1A23) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.volunteer_activism, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Zakat Calculator',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: _showZakatPercentageDialog,
                      icon: const Icon(Icons.edit, size: 14),
                      label: Text('$_zakatPercentage% Rate', style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Calculated Zakat: ${(_summary?.zakatAmount ?? 0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Based on Monthly Income (${(_summary?.totalIncome ?? 0).toStringAsFixed(2)}) @ $_zakatPercentage%',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Expense Breakdown list
          const Text(
            'Expense Category Breakdown',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),

          breakdown.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No expenses recorded for breakdown.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                )
              : Column(
                  children: breakdown.entries.map((e) {
                    final catName = e.key;
                    final amount = e.value;
                    final double ratio = (amount / (totalExpense > 0 ? totalExpense : 1.0)).clamp(0.0, 1.0);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C1A23) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(catName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                '${amount.toStringAsFixed(2)} (${(ratio * 100).toStringAsFixed(1)}%)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: ratio,
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
}
