import 'package:flutter/material.dart';
import '../services/zikr_service.dart';
import '../screens/zikr_detail_sheet.dart';

class ZikrDashboard extends StatefulWidget {
  final String uid;

  const ZikrDashboard({
    super.key,
    required this.uid,
  });

  @override
  State<ZikrDashboard> createState() => _ZikrDashboardState();
}

class _ZikrDashboardState extends State<ZikrDashboard> {
  final _zikrService = ZikrService();
  List<ZikrCounter> _counters = [];
  bool _isLoading = true;

  int _todayTotal = 0;
  int _lifetimeTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadCounters();
  }

  Future<void> _loadCounters() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final list = await _zikrService.getCounters(widget.uid);
      int todaySum = 0;
      int lifetimeSum = 0;
      for (final c in list) {
        todaySum += c.dailyCount;
        lifetimeSum += c.lifetimeCount;
      }

      if (mounted) {
        setState(() {
          _counters = list;
          _todayTotal = todaySum;
          _lifetimeTotal = lifetimeSum;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading counters: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _togglePin(ZikrCounter counter) async {
    final updated = ZikrCounter(
      id: counter.id,
      name: counter.name,
      iconName: counter.iconName,
      hasTarget: counter.hasTarget,
      targetValue: counter.targetValue,
      isPinned: !counter.isPinned,
      dailyCount: counter.dailyCount,
      monthlyCount: counter.monthlyCount,
      lifetimeCount: counter.lifetimeCount,
      lastUpdatedDate: counter.lastUpdatedDate,
      lastUpdatedMonth: counter.lastUpdatedMonth,
      currentMonthLogs: counter.currentMonthLogs,
    );

    await _zikrService.saveCounter(widget.uid, updated);
    _loadCounters();
  }

  Future<void> _showAddCounterDialog() async {
    if (_counters.length >= 10) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Limit Reached'),
          content: const Text('You can create a maximum of 10 counters. Please delete an existing counter to add a new one.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final targetController = TextEditingController(text: '100');
    
    String selectedIconName = 'mosque';
    bool hasTarget = false;

    final iconsList = ['mosque', 'prayer_beads', 'menu_book', 'star', 'favorite', 'health', 'shield', 'lightbulb', 'check'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Zikr Counter'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Counter Name (e.g. Astaghfar)',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 30,
                    ),
                    const SizedBox(height: 12),
                    
                    const Text('Select Icon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    // Icon grid selection
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: iconsList.map((iconName) {
                        final isSelected = selectedIconName == iconName;
                        return ChoiceChip(
                          label: Icon(
                            _getIconData(iconName),
                            size: 18,
                            color: isSelected ? Colors.white : theme.colorScheme.primary,
                          ),
                          selected: isSelected,
                          selectedColor: theme.colorScheme.primary,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedIconName = iconName;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Target Settings
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Set Daily Target Limit', style: TextStyle(fontWeight: FontWeight.bold)),
                        Switch(
                          value: hasTarget,
                          onChanged: (val) {
                            setDialogState(() {
                              hasTarget = val;
                            });
                          },
                        ),
                      ],
                    ),
                    
                    if (hasTarget) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: targetController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Daily Target Count',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) return;
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      final name = nameController.text.trim();
      final targetVal = hasTarget ? (int.tryParse(targetController.text.trim()) ?? 100) : 0;
      final newId = DateTime.now().millisecondsSinceEpoch.toString();

      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final counter = ZikrCounter(
        id: newId,
        name: name,
        iconName: selectedIconName,
        hasTarget: hasTarget,
        targetValue: targetVal,
        isPinned: false,
        dailyCount: 0,
        monthlyCount: 0,
        lifetimeCount: 0,
        lastUpdatedDate: todayStr,
        lastUpdatedMonth: monthStr,
        currentMonthLogs: {},
      );

      await _zikrService.saveCounter(widget.uid, counter);
      _loadCounters();
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

  void _openCounterDetail(ZikrCounter counter) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ZikrDetailSheet(
        uid: widget.uid,
        counter: counter,
        onDeleteOrUpdate: _loadCounters,
      ),
    ).then((_) => _loadCounters());
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
                // Global Count summary block
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF121212) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildGlobalMetric('Recitations Today', _todayTotal, Colors.blue),
                        Container(width: 1, height: 40, color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                        _buildGlobalMetric('Lifetime Total', _lifetimeTotal, Colors.green),
                      ],
                    ),
                  ),
                ),
                
                // List of counters
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12.0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black : Colors.white.withValues(alpha: 0.6),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32.0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'My Zikr Counters (${_counters.length}/10)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle, size: 24),
                              color: theme.colorScheme.primary,
                              onPressed: _showAddCounterDialog,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _counters.isEmpty
                              ? _buildEmptyState()
                              : ListView.separated(
                                  itemCount: _counters.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                                  padding: const EdgeInsets.only(bottom: 80),
                                  itemBuilder: (context, index) {
                                    final counter = _counters[index];
                                    return _ZikrCounterCard(
                                      counter: counter,
                                      iconData: _getIconData(counter.iconName),
                                      onIncrement: () async {
                                        await _zikrService.incrementCounter(widget.uid, counter.id);
                                        // Update local summaries dynamically for high responsiveness
                                        setState(() {
                                          counter.dailyCount++;
                                          counter.monthlyCount++;
                                          counter.lifetimeCount++;
                                          _todayTotal++;
                                          _lifetimeTotal++;
                                        });
                                      },
                                      onTogglePin: () => _togglePin(counter),
                                      onTapDetail: () => _openCounterDetail(counter),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCounterDialog,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGlobalMetric(String title, int count, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.radio_button_checked,
            size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'No counters created yet.',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              'Tap the + button to add custom recitation counters (Darood, Astaghfar, Quran page counts, etc.)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZikrCounterCard extends StatefulWidget {
  final ZikrCounter counter;
  final IconData iconData;
  final VoidCallback onIncrement;
  final VoidCallback onTogglePin;
  final VoidCallback onTapDetail;

  const _ZikrCounterCard({
    required this.counter,
    required this.iconData,
    required this.onIncrement,
    required this.onTogglePin,
    required this.onTapDetail,
  });

  @override
  State<_ZikrCounterCard> createState() => _ZikrCounterCardState();
}

class _ZikrCounterCardState extends State<_ZikrCounterCard> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onIncrement();
    _animController.forward().then((_) {
      _animController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Check if daily target achieved
    final double targetProgress = widget.counter.hasTarget && widget.counter.targetValue > 0
        ? (widget.counter.dailyCount / widget.counter.targetValue).clamp(0.0, 1.0)
        : 0.0;
    
    final bool targetAchieved = widget.counter.hasTarget && widget.counter.dailyCount >= widget.counter.targetValue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.iconData,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              
              // Counter details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.counter.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (targetAchieved)
                          const Padding(
                            padding: EdgeInsets.only(left: 4.0),
                            child: Icon(Icons.stars, color: Colors.amber, size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Today: ${widget.counter.dailyCount} ${widget.counter.hasTarget ? "/ ${widget.counter.targetValue}" : ""}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              
              // Pin Button
              IconButton(
                icon: Icon(
                  widget.counter.isPinned ? Icons.star : Icons.star_border,
                  color: widget.counter.isPinned ? Colors.amber : Colors.grey,
                  size: 20,
                ),
                onPressed: widget.onTogglePin,
              ),
              
              // Info Button
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.grey, size: 20),
                onPressed: widget.onTapDetail,
              ),
              
              // Clickable count bubble trigger with bounce anim
              GestureDetector(
                onTap: _handleTap,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: targetAchieved
                          ? Colors.green
                          : theme.colorScheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: (targetAchieved ? Colors.green : theme.colorScheme.primary).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Text(
                      '${widget.counter.dailyCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Progress bar for Target Counters
          if (widget.counter.hasTarget) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: targetProgress,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(targetAchieved ? Colors.green : theme.colorScheme.primary),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
