import 'package:flutter/material.dart';
import '../widgets/namaz_dashboard.dart';

class HomeTab extends StatefulWidget {
  final String uid;
  final int relationshipLevel;
  final int lovePoints;
  final String alinaMood;
  final Map<String, Map<String, dynamic>> last7DaysRecords;
  final bool isLoading;
  final VoidCallback onRefresh;

  const HomeTab({
    super.key,
    required this.uid,
    required this.relationshipLevel,
    required this.lovePoints,
    required this.alinaMood,
    required this.last7DaysRecords,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ─── Alina Hero Card ───────────────────────────────────────
        _buildAlinaHeroCard(theme, isDark),
        const SizedBox(height: 12),
        // ─── Namaz Tracker Widget ──────────────────────────────────
        NamazDashboard(uid: widget.uid, isEmbedded: true),
      ],
    );
  }

  Widget _buildAlinaHeroCard(ThemeData theme, bool isDark) {
    final lvl = widget.relationshipLevel;
    final pts = widget.lovePoints;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF25101A), const Color(0xFF121212)]
              : [const Color(0xFFFFF5F8), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.primary, width: 2.5),
                  image: const DecorationImage(
                    image: AssetImage('assets/alina.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                  border: Border.all(color: isDark ? const Color(0xFF1E0414) : Colors.white, width: 2),
                ),
                child: const Icon(Icons.favorite, color: Colors.white, size: 11),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Alina',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1A0010),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Lvl $lvl',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  widget.alinaMood,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                // Love points bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (pts % 100) / 100,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$pts pts',
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
