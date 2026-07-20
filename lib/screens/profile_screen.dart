import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';

class ProfileScreen extends StatefulWidget {
  final String uid;
  final String email;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChangeTheme;
  final bool isSandboxMode;

  const ProfileScreen({
    super.key,
    required this.uid,
    required this.email,
    required this.themeMode,
    required this.onChangeTheme,
    required this.isSandboxMode,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _syncManager = SyncManager();

  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _cityController = TextEditingController(text: 'Islamabad');
  final _bioController = TextEditingController();

  bool _isSaving = false;
  bool _isLoading = true;
  bool _isSyncing = false;
  String _syncStatus = '';
  String _lastSyncTime = 'Never';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    // Load last sync time and listen to sync updates
    _syncManager.init().then((_) {
      if (mounted) {
        setState(() {
          _lastSyncTime = _syncManager.lastSyncTime;
          _syncStatus = _syncManager.syncStatus;
        });
      }
    });
    _syncManager.addListener(_onSyncUpdate);
  }

  void _onSyncUpdate() {
    if (mounted) {
      setState(() {
        _isSyncing = _syncManager.isSyncing;
        _syncStatus = _syncManager.syncStatus;
        _lastSyncTime = _syncManager.lastSyncTime;
      });
    }
  }

  @override
  void dispose() {
    _syncManager.removeListener(_onSyncUpdate);
    _nameController.dispose();
    _dobController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<File> _sandboxProfileFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/profile_${widget.uid}.json');
  }

  Future<void> _loadProfile() async {
    try {
      Map<String, dynamic>? data;

      if (!widget.isSandboxMode) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('profile')
            .doc('info')
            .get();
        if (doc.exists) data = doc.data();
      } else {
        final file = await _sandboxProfileFile();
        if (await file.exists()) {
          data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        }
      }

      if (data != null && mounted) {
        _nameController.text = data['name'] ?? '';
        _dobController.text = data['dob'] ?? '';
        _cityController.text = data['city'] ?? 'Islamabad';
        _bioController.text = data['bio'] ?? '';
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final data = {
        'name': _nameController.text.trim(),
        'dob': _dobController.text.trim(),
        'city': _cityController.text.trim(),
        'bio': _bioController.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      // Always save locally first
      final file = await _sandboxProfileFile();
      await file.writeAsString(jsonEncode(data));

      // Also push to Firebase if connected
      if (!widget.isSandboxMode) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('profile')
            .doc('info')
            .set(data, SetOptions(merge: true))
            .catchError((e) => debugPrint('Profile Firebase sync error: $e'));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile saved successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _syncNow() async {
    if (_isSyncing) return;
    final messenger = ScaffoldMessenger.of(context);
    final result = await _syncManager.syncAll(widget.uid);
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.failed == 0 ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _pickDOB() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dobController.text = '${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final initials = _nameController.text.isNotEmpty
        ? _nameController.text.trim()[0].toUpperCase()
        : widget.email[0].toUpperCase();

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // ─── Avatar Section ──────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 2)],
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _nameController.text.isNotEmpty ? _nameController.text : 'Set Your Name',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.email,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade500),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.isSandboxMode
                            ? Colors.orange.withValues(alpha: 0.15)
                            : Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.isSandboxMode ? Icons.cloud_off : Icons.cloud_done,
                            size: 12,
                            color: widget.isSandboxMode ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            widget.isSandboxMode ? 'Local Mode' : 'Cloud Synced',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: widget.isSandboxMode ? Colors.orange : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ─── My Info ─────────────────────────────────────────
              _buildSectionHeader('My Info', Icons.person_outline, theme),
              const SizedBox(height: 12),
              _buildCard(isDark, theme, [
                _buildTextField('Full Name', Icons.badge_outlined, _nameController, () => setState(() {})),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _pickDOB,
                  child: AbsorbPointer(
                    child: _buildTextField('Date of Birth', Icons.cake_outlined, _dobController, null, hint: 'DD-MM-YYYY'),
                  ),
                ),
                const SizedBox(height: 14),
                _buildCityDropdown(isDark, theme),
                const SizedBox(height: 14),
                _buildTextField('About Me / Bio', Icons.notes_outlined, _bioController, null, maxLines: 3),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_isSaving ? 'Saving…' : 'Save Profile', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),

              // ─── App Theme ────────────────────────────────────────
              _buildSectionHeader('Appearance', Icons.palette_outlined, theme),
              const SizedBox(height: 12),
              _buildCard(isDark, theme, [
                Row(
                  children: [
                    _buildThemeOption(ThemeMode.light, Icons.light_mode, 'Light', theme, isDark),
                    const SizedBox(width: 8),
                    _buildThemeOption(ThemeMode.dark, Icons.dark_mode, 'Dark', theme, isDark),
                    const SizedBox(width: 8),
                    _buildThemeOption(ThemeMode.system, Icons.phone_android, 'System', theme, isDark),
                  ],
                ),
              ]),
              const SizedBox(height: 24),

              // ─── Cloud Sync ───────────────────────────────────────
              _buildSectionHeader('Cloud Backup & Sync', Icons.cloud_sync_outlined, theme),
              const SizedBox(height: 12),
              _buildCard(isDark, theme, [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isSandboxMode ? 'Local Sandbox Mode' : 'Cloud Sync Connected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: widget.isSandboxMode ? Colors.orange : Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Last Synced: $_lastSyncTime',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          if (_syncStatus.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              _syncStatus,
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.primary.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isSyncing ? null : _syncNow,
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.sync_rounded, size: 16),
                      label: Text(_isSyncing ? 'Syncing…' : 'Sync Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: theme.colorScheme.primary.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 24),

              // ─── Account Actions ──────────────────────────────────
              _buildSectionHeader('Account', Icons.manage_accounts_outlined, theme),
              const SizedBox(height: 12),
              _buildCard(isDark, theme, [
                _buildActionRow(Icons.logout, 'Sign Out', Colors.orange, () async {
                  await _authService.signOut();
                }, theme),
                const Divider(height: 24),
                _buildActionRow(Icons.delete_forever, 'Delete Account', Colors.red, () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Delete Account?'),
                      content: const Text('All your data will be permanently erased. This cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final error = await _authService.deleteAccount();
                    if (error != null) {
                      messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                    }
                  }
                }, theme),
              ]),
            ],
          );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(bool isDark, ThemeData theme, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller, VoidCallback? onChanged, {String? hint, int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged != null ? (_) => onChanged() : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
      ),
    );
  }

  Widget _buildCityDropdown(bool isDark, ThemeData theme) {
    final cities = ['Islamabad', 'Karachi', 'Lahore', 'Dhaka', 'Dubai', 'London', 'New York'];
    final currentCity = cities.contains(_cityController.text) ? _cityController.text : 'Islamabad';
    return DropdownButtonFormField<String>(
      initialValue: currentCity,
      decoration: InputDecoration(
        labelText: 'City / Location',
        prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.primary)),
      ),
      dropdownColor: isDark ? const Color(0xFF121212) : Colors.white,
      items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: (val) {
        if (val != null) _cityController.text = val;
      },
    );
  }

  Widget _buildThemeOption(ThemeMode mode, IconData icon, String label, ThemeData theme, bool isDark) {
    final isSelected = widget.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onChangeTheme(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : (isDark ? const Color(0xFF2A1A2E) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow(IconData icon, String label, Color color, VoidCallback onTap, ThemeData theme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
            const Spacer(),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }
}
