import 'package:flutter/material.dart';
import 'namaz_dashboard.dart';
import 'zikr_dashboard.dart';
import 'calendar_dashboard.dart';

class IslamicHub extends StatefulWidget {
  final String uid;

  const IslamicHub({super.key, required this.uid});

  @override
  State<IslamicHub> createState() => _IslamicHubState();
}

class _IslamicHubState extends State<IslamicHub> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _tabs = [
    {'label': 'Namaz', 'icon': Icons.mosque_outlined},
    {'label': 'Zikr', 'icon': Icons.radio_button_checked},
    {'label': 'Calendar', 'icon': Icons.calendar_month_outlined},
  ];

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
              children: List.generate(_tabs.length, (i) {
                final isSelected = i == _selectedIndex;
                final tab = _tabs[i];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
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
                          Icon(
                            tab['icon'] as IconData,
                            size: 15,
                            color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.grey.shade600),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tab['label'] as String,
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
              }),
            ),
          ),
        ),

        // ─── Content Area ──────────────────────────────────────────
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              NamazDashboard(uid: widget.uid),
              ZikrDashboard(uid: widget.uid),
              CalendarDashboard(uid: widget.uid),
            ],
          ),
        ),
      ],
    );
  }
}
