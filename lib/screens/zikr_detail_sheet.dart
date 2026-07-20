import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:path_provider/path_provider.dart';
import '../services/zikr_service.dart';

class ZikrDetailSheet extends StatefulWidget {
  final String uid;
  final ZikrCounter counter;
  final VoidCallback onDeleteOrUpdate;

  const ZikrDetailSheet({
    super.key,
    required this.uid,
    required this.counter,
    required this.onDeleteOrUpdate,
  });

  @override
  State<ZikrDetailSheet> createState() => _ZikrDetailSheetState();
}

class _ZikrDetailSheetState extends State<ZikrDetailSheet> {
  final _zikrService = ZikrService();
  
  late ZikrCounter _counter;
  String _selectedMonthKey = '';
  Map<String, int> _renderedLogs = {};
  int _renderedTotal = 0;
  bool _isLoadingHistory = false;

  List<String> _historyMonths = [];

  @override
  void initState() {
    super.initState();
    _counter = widget.counter;
    
    final now = DateTime.now();
    _selectedMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _renderedLogs = _counter.currentMonthLogs;
    _renderedTotal = _counter.monthlyCount;

    _generateHistoryMonthKeys();
  }

  void _generateHistoryMonthKeys() {
    final now = DateTime.now();
    final List<String> months = [];
    // Last 6 months lookup dropdown options
    for (int i = 0; i < 6; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      months.add(key);
    }
    _historyMonths = months;
  }

  Future<void> _loadHistory(String monthKey) async {
    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    setState(() {
      _selectedMonthKey = monthKey;
      _isLoadingHistory = true;
    });

    if (monthKey == currentMonthKey) {
      setState(() {
        _renderedLogs = _counter.currentMonthLogs;
        _renderedTotal = _counter.monthlyCount;
        _isLoadingHistory = false;
      });
    } else {
      final history = await _zikrService.getMonthlyHistory(widget.uid, _counter.id, monthKey);
      if (mounted) {
        setState(() {
          if (history != null) {
            final logsMap = history['dailyLogs'] as Map<dynamic, dynamic>? ?? {};
            final Map<String, int> castedLogs = {};
            logsMap.forEach((k, v) {
              castedLogs[k.toString()] = (v as num).toInt();
            });
            _renderedLogs = castedLogs;
            _renderedTotal = (history['totalCount'] ?? 0) as int;
          } else {
            _renderedLogs = {};
            _renderedTotal = 0;
          }
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _editDayLog(String dateStr) async {
    // Only allow editing if it's the current month (or allow past months as well)
    final currentCount = _renderedLogs[dateStr] ?? 0;
    final textController = TextEditingController(text: currentCount.toString());

    final newCount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Logs for $dateStr'),
        content: TextField(
          controller: textController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Count Value',
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
              final val = int.tryParse(textController.text.trim()) ?? 0;
              Navigator.of(context).pop(val);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newCount != null) {
      final now = DateTime.now();
      final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      if (_selectedMonthKey == currentMonthKey) {
        // Update live counter values
        final difference = newCount - currentCount;
        setState(() {
          _counter.currentMonthLogs[dateStr] = newCount;
          _counter.monthlyCount += difference;
          _counter.lifetimeCount += difference;
          
          final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          if (dateStr == todayStr) {
            _counter.dailyCount = newCount;
          }
          _renderedLogs = _counter.currentMonthLogs;
          _renderedTotal = _counter.monthlyCount;
        });
        
        await _zikrService.saveCounter(widget.uid, _counter);
        widget.onDeleteOrUpdate();
      } else {
        // Update historical document
        final difference = newCount - currentCount;
        setState(() {
          _renderedLogs[dateStr] = newCount;
          _renderedTotal += difference;
          _counter.lifetimeCount += difference; // Lifetime increases regardless of date
        });

        // 1. Save history document
        await _zikrService.saveCounter(widget.uid, _counter); // Updates lifetime count
        await _zikrService.saveCounter(widget.uid, _counter); // Sync live counter changes
        
        // Simulating the archive update
        final dynamicHistory = {
          'month': _selectedMonthKey,
          'totalCount': _renderedTotal,
          'dailyLogs': _renderedLogs,
        };
        
        if (!_zikrService.isSandboxMode) {
          final fsInstance = fs.FirebaseFirestore.instance;
          await fsInstance
              .collection('users')
              .doc(widget.uid)
              .collection('counters')
              .doc(_counter.id)
              .collection('history')
              .doc(_selectedMonthKey)
              .set(dynamicHistory);
        } else {
          // sandbox save
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/alina_sandbox_history_${widget.uid}_${_counter.id}_$_selectedMonthKey.json');
          await file.writeAsString(jsonEncode(dynamicHistory));
        }
        widget.onDeleteOrUpdate();
      }
    }
  }

  Future<void> _resetCounter() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Counter?'),
        content: const Text('This will set today\'s count to 0. Lifetime count will not be affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        final now = DateTime.now();
        final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final todayCount = _counter.dailyCount;
        
        _counter.dailyCount = 0;
        _counter.monthlyCount -= todayCount;
        _counter.lifetimeCount -= todayCount;
        _counter.currentMonthLogs[todayStr] = 0;
        
        _renderedLogs = _counter.currentMonthLogs;
        _renderedTotal = _counter.monthlyCount;
      });
      await _zikrService.saveCounter(widget.uid, _counter);
      widget.onDeleteOrUpdate();
    }
  }

  Future<void> _deleteCounter() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Counter?'),
        content: Text('Are you sure you want to delete "${_counter.name}" and all of its history? This action is permanent.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) {
        Navigator.of(context).pop(); // Close detail sheet
      }
      await _zikrService.deleteCounter(widget.uid, _counter.id);
      widget.onDeleteOrUpdate();
    }
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'mosque': return Icons.mosque;
      case 'prayer_beads': return Icons.circle;
      case 'menu_book': return Icons.menu_book;
      case 'star': return Icons.star;
      case 'favorite': return Icons.favorite;
      case 'health': return Icons.healing;
      case 'shield': return Icons.shield;
      case 'lightbulb': return Icons.lightbulb;
      case 'check': return Icons.check;
      default: return Icons.radio_button_checked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Calculate calendar grid properties for the selected month
    final parts = _selectedMonthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayOfWeek = DateTime(year, month, 1).weekday; // 1 = Monday, 7 = Sunday
    
    // Grid size includes empty spacers before the first day of the month
    final gridOffset = firstDayOfWeek - 1; // standard offset for Mon=0, Tue=1, etc.
    final totalGridCells = daysInMonth + gridOffset;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1016) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          const SizedBox(height: 12),
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
          
          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconData(_counter.iconName),
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _counter.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _counter.hasTarget ? 'Target: ${_counter.targetValue}' : 'Unlimited Count Mode',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Stat metric blocks
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricBlock('Today', _counter.dailyCount, Colors.blue),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricBlock('This Month', _counter.monthlyCount, theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricBlock('Lifetime', _counter.lifetimeCount, Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Month historical navigator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Monthly History Calendar',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C1A23) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedMonthKey,
                          underline: const SizedBox(),
                          dropdownColor: isDark ? const Color(0xFF1E1016) : Colors.white,
                          onChanged: (newMonthKey) {
                            if (newMonthKey != null) {
                              _loadHistory(newMonthKey);
                            }
                          },
                          items: _historyMonths.map((mKey) {
                            final p = mKey.split('-');
                            final yr = p[0];
                            final moIndex = int.parse(p[1]) - 1;
                            final moNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                            return DropdownMenuItem<String>(
                              value: mKey,
                              child: Text('${moNames[moIndex]} $yr', style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Calendar grid
                  _isLoadingHistory
                      ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
                      : Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C1A23) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.05)),
                          ),
                          child: Column(
                            children: [
                              // Weekday Headers
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                                  return SizedBox(
                                    width: 32,
                                    child: Text(
                                      day,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),
                              // Month Days Grid
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  crossAxisSpacing: 6,
                                  mainAxisSpacing: 6,
                                  childAspectRatio: 1.0,
                                ),
                                itemCount: totalGridCells,
                                itemBuilder: (context, index) {
                                  if (index < gridOffset) {
                                    return const SizedBox(); // padding for days offset
                                  }
                                  
                                  final dayNum = index - gridOffset + 1;
                                  final dayDateStr = '$_selectedMonthKey-${dayNum.toString().padLeft(2, '0')}';
                                  final dayCount = _renderedLogs[dayDateStr] ?? 0;
                                  final hasLogs = dayCount > 0;
                                  
                                  return GestureDetector(
                                    onTap: () => _editDayLog(dayDateStr),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: hasLogs
                                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: hasLogs
                                              ? theme.colorScheme.primary.withValues(alpha: 0.3)
                                              : Colors.grey.shade300.withValues(alpha: isDark ? 0.1 : 0.5),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '$dayNum',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: hasLogs ? FontWeight.bold : FontWeight.normal,
                                              color: hasLogs ? theme.colorScheme.primary : (isDark ? Colors.white70 : Colors.black87),
                                            ),
                                          ),
                                          if (hasLogs)
                                            Text(
                                              '$dayCount',
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.primary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                  
                  const SizedBox(height: 32),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetCounter,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Reset Today'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _deleteCounter,
                          icon: const Icon(Icons.delete, size: 18),
                          label: const Text('Delete Counter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBlock(String label, int value, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C1A23) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
