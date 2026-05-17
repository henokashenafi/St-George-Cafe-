import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/models/app_user.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/locales/app_localizations.dart';
import 'package:st_george_pos/core/database_helper.dart';
import 'package:st_george_pos/services/audit_service.dart';
import 'package:st_george_pos/models/settings.dart';
import 'package:st_george_pos/core/widgets/top_toaster.dart';
import 'package:printing/printing.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _serviceChargeController = TextEditingController();
  final _cafeNameController = TextEditingController();
  final _cafeAddressController = TextEditingController();
  final _cafePhoneController = TextEditingController();
  final _cafeVatController = TextEditingController();
  final _cafeCurrencyController = TextEditingController();
  final _vatRateController = TextEditingController();

  bool _discountEnabled = true;
  bool _saving = false;
  bool _initialized = false;

  List<Printer> _printers = [];
  String? _selectedPrinterName;
  bool _isLoadingPrinters = false;

  @override
  void dispose() {
    _serviceChargeController.dispose();
    _cafeNameController.dispose();
    _cafeAddressController.dispose();
    _cafePhoneController.dispose();
    _cafeVatController.dispose();
    _cafeCurrencyController.dispose();
    _vatRateController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (_initialized) return;

    final settings = await ref.read(appSettingsProvider.future);
    final cafe = await ref.read(cafeSettingsProvider.future);

    _serviceChargeController.text = settings['service_charge_percent'] ?? '5.0';
    _discountEnabled = (settings['discount_enabled'] ?? 'true') == 'true';

    _cafeNameController.text = cafe.name;
    _cafeAddressController.text = cafe.address;
    _cafePhoneController.text = cafe.phone;
    _cafeVatController.text = cafe.vatNumber;
    _cafeCurrencyController.text = cafe.currency;
    _vatRateController.text = cafe.vatRate.toString();

    _selectedPrinterName = settings['default_printer_name'];

    setState(() => _initialized = true);
    _fetchPrinters();
  }

  Future<void> _fetchPrinters() async {
    if (!mounted) return;
    setState(() => _isLoadingPrinters = true);
    try {
      // 5-second timeout: some Windows printer drivers hang EnumPrinters indefinitely
      final printers = await Printing.listPrinters().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[Settings] listPrinters timed out after 5s');
          return [];
        },
      );
      if (mounted) {
        setState(() => _printers = printers);
      }
    } catch (e) {
      debugPrint('[Settings] Error fetching printers: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPrinters = false);
    }
  }

  Future<void> _saveSettings() async {
    final currentUser = ref.read(authProvider);
    if (currentUser == null) return;
    final charge = double.tryParse(_serviceChargeController.text);
    if (charge == null || charge < 0 || charge > 100) {
      TopToaster.show(
        context,
        ref.t('settings.serviceChargeError'),
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(posRepositoryProvider);

    // Save Billing
    await repo.setSetting(
      'service_charge_percent',
      charge.toString(),
      currentUser.id!,
    );
    await repo.setSetting(
      'discount_enabled',
      _discountEnabled.toString(),
      currentUser.id!,
    );
    if (_selectedPrinterName != null) {
      await repo.setSetting(
        'default_printer_name',
        _selectedPrinterName!,
        currentUser.id!,
      );
    } else {
      await repo.setSetting('default_printer_name', '', currentUser.id!);
    }

    // Save Cafe Info
    final newCafe = CafeSettings(
      name: _cafeNameController.text,
      address: _cafeAddressController.text,
      phone: _cafePhoneController.text,
      vatNumber: _cafeVatController.text,
      currency: _cafeCurrencyController.text,
      vatRate: double.tryParse(_vatRateController.text) ?? 0.0,
    );
    await repo.saveSettings(newCafe);

    // Sync VAT with pos_charges
    final charges = await ref.read(chargesProvider.future);
    try {
      final vatCharge = charges.firstWhere(
        (c) => c.name.toUpperCase() == 'VAT',
      );
      await repo.updateCharge(
        vatCharge.id!,
        vatCharge.copyWith(value: newCafe.vatRate).toMap(),
      );
    } catch (e) {
      await repo.addCharge({
        'name': 'VAT',
        'type': 'addition',
        'value': newCafe.vatRate,
        'is_active': 1,
      });
    }
    ref.invalidate(chargesProvider);

    await ref
        .read(auditServiceProvider)
        .log(
          'Settings Updated',
          details: 'User: ${currentUser.username}, SC: $charge%',
        );

    ref.invalidate(appSettingsProvider);
    ref.invalidate(cafeSettingsProvider);

    setState(() => _saving = false);
    if (mounted) {
      TopToaster.show(context, ref.t('settings.saved'));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final settingsAsync = ref.watch(appSettingsProvider);

    return FutureBuilder(
      future: _loadSettings(),
      builder: (context, snapshot) {
        if (!_initialized)
          return const Center(child: CircularProgressIndicator());
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
                      const SizedBox(height: 16),
                      Text(
                        ref.t('settings.vatRate'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 200,
                        child: TextFormField(
                          controller: _vatRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDec(ref.t('settings.vatRateHint')),
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
              _SectionHeader(title: ref.t('settings.cafeInformation')),
              GlassContainer(
                opacity: 0.05,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildTextField(
                        _cafeNameController,
                        ref.t('settings.cafeName'),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _cafeAddressController,
                        ref.t('settings.address'),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _cafePhoneController,
                        ref.t('settings.phone'),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _cafeVatController,
                        ref.t('settings.vatNumber'),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _cafeCurrencyController,
                        ref.t('settings.currencyLabel'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _SectionHeader(title: ref.t('settings.hardwarePrinters')),
              GlassContainer(
                opacity: 0.05,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.t('settings.defaultPrinter'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingPrinters)
                        const CircularProgressIndicator()
                      else
                        DropdownButtonFormField<String?>(
                          value: _selectedPrinterName == ''
                              ? null
                              : _selectedPrinterName,
                          dropdownColor: const Color(0xFF1A1A1A),
                          decoration: _inputDec(
                            ref.t('settings.selectPrinter'),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(ref.t('settings.noPrinter')),
                            ),
                            ..._printers.map(
                              (p) => DropdownMenuItem(
                                value: p.name,
                                child: Text(p.name),
                              ),
                            ),
                            if (_selectedPrinterName != null &&
                                _selectedPrinterName != '' &&
                                !_printers.any(
                                  (p) => p.name == _selectedPrinterName,
                                ))
                              DropdownMenuItem(
                                value: _selectedPrinterName,
                                child: Text(
                                  ref.t(
                                    'settings.printerOffline',
                                    replacements: {
                                      'name': _selectedPrinterName!,
                                    },
                                  ),
                                ),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedPrinterName = v),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        ref.t('settings.printerDescription'),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
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
                        ref.t('settings.saveAll'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDec(label),
        ),
      ],
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white38),
    filled: true,
    fillColor: Colors.white.withOpacity(0.06),
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: Color(0xFFD4AF37)),
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
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
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
                            borderRadius: BorderRadius.zero,
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
    final nameController = TextEditingController(text: existing?.username ?? '');
    final passController = TextEditingController();
    UserRole selectedRole = existing?.role ?? UserRole.cashier;
    bool isActive = existing?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

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
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: ref.t('auth.username'),
                      labelStyle: const TextStyle(color: Colors.white54),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? ref.t('common.required')
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: existing == null
                          ? ref.t('auth.password')
                          : ref.t('settings.newPasswordHint'),
                      labelStyle: const TextStyle(color: Colors.white54),
                    ),
                    validator: (v) {
                      if (existing == null && (v == null || v.isEmpty)) {
                        return ref.t('common.required');
                      }
                      return null;
                    },
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
                if (!formKey.currentState!.validate()) return;
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
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
            const SizedBox(width: 8),
            Text(ref.t('settings.deleteUser')),
          ],
        ),
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
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
