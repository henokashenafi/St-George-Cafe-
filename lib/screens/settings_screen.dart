import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/models/app_user.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/locales/app_localizations.dart';
import 'package:st_george_pos/core/database_helper.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _serviceChargeController = TextEditingController();
  bool _discountEnabled = true;
  bool _saving = false;

  @override
  void dispose() {
    _serviceChargeController.dispose();
    super.dispose();
  }

  void _loadSettings(Map<String, String> settings) {
    if (_serviceChargeController.text.isEmpty) {
      _serviceChargeController.text =
          settings['service_charge_percent'] ?? '5.0';
    }
    _discountEnabled = (settings['discount_enabled'] ?? 'true') == 'true';
  }

  Future<void> _saveSettings() async {
    final currentUser = ref.read(authProvider);
    if (currentUser == null) return;
    final charge = double.tryParse(_serviceChargeController.text);
    if (charge == null || charge < 0 || charge > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.t('settings.serviceChargeError'))),
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(posRepositoryProvider);
    await repo.setSetting('service_charge_percent', charge.toString(), currentUser.id!);
    await repo.setSetting('discount_enabled', _discountEnabled.toString(), currentUser.id!);
    ref.invalidate(appSettingsProvider);
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ref.t('settings.saved'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);

    return settingsAsync.when(
      data: (settings) {
        _loadSettings(settings);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(title: ref.t('settings.billing')),
              GlassContainer(
                opacity: 0.05,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.t('settings.serviceChargeLabel'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 200,
                        child: TextFormField(
                          controller: _serviceChargeController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDec(
                            ref.t('settings.serviceChargeHint'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Switch(
                            value: _discountEnabled,
                            activeColor: const Color(0xFFD4AF37),
                            onChanged: (v) =>
                                setState(() => _discountEnabled = v),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            ref.t('settings.enableDiscount'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saving ? null : _saveSettings,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        ref.t('settings.save'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('${ref.t('common.error')}: $e'),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white38),
    filled: true,
    fillColor: Colors.white.withOpacity(0.06),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFD4AF37)),
    ),
  );
}

// ── User Management ───────────────────────────────────────────────────────

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final usersAsync = ref.watch(usersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionHeader(title: ref.t('settings.users')),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_outlined),
              label: Text(ref.t('settings.addUser')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _showUserDialog(context, ref, null),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: usersAsync.when(
            data: (users) => GlassContainer(
              opacity: 0.05,
              child: ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  final u = users[index];
                  final isDirector = u.role == UserRole.director;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isDirector
                          ? const Color(0xFFD4AF37).withOpacity(0.2)
                          : Colors.white10,
                      child: Icon(
                        isDirector
                            ? Icons.admin_panel_settings_outlined
                            : Icons.point_of_sale,
                        color: isDirector
                            ? const Color(0xFFD4AF37)
                            : Colors.white54,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      u.username,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      isDirector
                          ? ref.t('settings.director')
                          : ref.t('settings.cashier'),
                      style: TextStyle(
                        color: isDirector
                            ? const Color(0xFFD4AF37)
                            : Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: u.isActive
                                ? const Color(0xFF006B3C).withOpacity(0.2)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            u.isActive
                                ? ref.t('settings.active')
                                : ref.t('settings.inactive'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: u.isActive
                                  ? const Color(0xFF006B3C)
                                  : Colors.white38,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Colors.white54,
                          ),
                          onPressed: () => _showUserDialog(context, ref, u),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _confirmDelete(context, ref, u),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('${ref.t('common.error')}: $e'),
          ),
        ),
      ],
    );
  }

  void _showUserDialog(BuildContext context, WidgetRef ref, AppUser? existing) {
    final nameController = TextEditingController(
      text: existing?.username ?? '',
    );
    final passController = TextEditingController();
    UserRole selectedRole = existing?.role ?? UserRole.cashier;
    bool isActive = existing?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            existing == null
                ? ref.t('settings.addUser')
                : ref.t('settings.editUser'),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: ref.t('auth.username'),
                    labelStyle: const TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: existing == null
                        ? ref.t('auth.password')
                        : ref.t('settings.newPasswordHint'),
                    labelStyle: const TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: ref.t('settings.role'),
                    labelStyle: const TextStyle(color: Colors.white54),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: UserRole.cashier,
                      child: Text(ref.t('roles.cashier')),
                    ),
                    DropdownMenuItem(
                      value: UserRole.director,
                      child: Text(ref.t('roles.director')),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => selectedRole = v!),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Switch(
                      value: isActive,
                      activeColor: const Color(0xFFD4AF37),
                      onChanged: (v) => setDialogState(() => isActive = v),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ref.t('settings.active'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ref.t('common.cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                if (existing == null && passController.text.isEmpty) return;
                final repo = ref.read(posRepositoryProvider);
                final hash = passController.text.isNotEmpty
                    ? DatabaseHelper.hashPassword(passController.text)
                    : existing!.passwordHash;
                final user = AppUser(
                  id: existing?.id,
                  username: nameController.text.trim(),
                  passwordHash: hash,
                  role: selectedRole,
                  isActive: isActive,
                );
                if (existing == null) {
                  await repo.addUser(user);
                } else {
                  await repo.updateUser(user);
                }
                ref.invalidate(usersProvider);
                Navigator.pop(ctx);
              },
              child: Text(
                existing == null ? ref.t('common.add') : ref.t('common.save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(ref.t('settings.deleteUser')),
        content: Text(
          ref.t(
            'settings.deleteUserConfirm',
            replacements: {'username': user.username},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.t('common.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await ref.read(posRepositoryProvider).deleteUser(user.id!);
              ref.invalidate(usersProvider);
              Navigator.pop(ctx);
            },
            child: Text(ref.t('common.delete')),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
