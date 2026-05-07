import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/models/category.dart';
import 'package:st_george_pos/models/product.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/services/bill_service.dart';
import 'package:intl/intl.dart';


// ── Menu Management ───────────────────────────────────────────────────────

class MenuManagementScreen extends ConsumerStatefulWidget {
  const MenuManagementScreen({super.key});
  @override
  ConsumerState<MenuManagementScreen> createState() =>
      _MenuManagementScreenState();
}

class _MenuManagementScreenState extends ConsumerState<MenuManagementScreen> {
  int? selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsProvider(selectedCategoryId));

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: GlassContainer(
            opacity: 0.05,
            child: Column(
              children: [
                _Header(title: 'Categories', onAdd: () => _showCategoryDialog(context, null)),
                Expanded(
                  child: categoriesAsync.when(
                    data: (cats) => ListView.builder(
                      itemCount: cats.length,
                      itemBuilder: (_, i) {
                        final cat = cats[i];
                        return ListTile(
                          title: Text(cat.name,
                              style: TextStyle(
                                color: selectedCategoryId == cat.id
                                    ? const Color(0xFFD4AF37)
                                    : Colors.white,
                                fontWeight: selectedCategoryId == cat.id
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              )),
                          selected: selectedCategoryId == cat.id,
                          onTap: () =>
                              setState(() => selectedCategoryId = cat.id),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent, size: 20),
                            onPressed: () => _deleteCategory(cat.id!),
                          ),
                        );
                      },
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('$e'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: GlassContainer(
            opacity: 0.05,
            child: Column(
              children: [
                _Header(
                  title: 'Products',
                  onAdd: selectedCategoryId == null
                      ? null
                      : () => _showProductDialog(context, null),
                ),
                Expanded(
                  child: productsAsync.when(
                    data: (products) => ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (_, i) {
                        final p = products[i];
                        return ListTile(
                          leading: const CircleAvatar(
                              backgroundColor: Colors.white10,
                              child: Icon(Icons.fastfood,
                                  color: Color(0xFFD4AF37))),
                          title: Text(p.name),
                          subtitle:
                              Text('${p.price.toStringAsFixed(2)} ETB'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    color: Colors.white54, size: 20),
                                onPressed: () =>
                                    _showProductDialog(context, p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () => _deleteProduct(p.id!),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('$e'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCategoryDialog(BuildContext context, Category? existing) {
    final ctrl = TextEditingController(text: existing?.name ?? '');

    Future<void> doSave(BuildContext ctx) async {
      if (ctrl.text.trim().isEmpty) return;
      await ref.read(posRepositoryProvider).addCategory(ctrl.text.trim());
      ref.invalidate(categoriesProvider);
      Navigator.pop(ctx);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(existing == null ? 'Add Category' : 'Edit Category'),
        content: TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: Colors.white54)),
            onSubmitted: (_) => doSave(ctx)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black),
            onPressed: () => doSave(ctx),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showProductDialog(BuildContext context, Product? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
        text: existing != null ? existing.price.toString() : '');
    final priceFocus = FocusNode();

    Future<void> doSave(BuildContext ctx) async {
      final price = double.tryParse(priceCtrl.text);
      if (nameCtrl.text.trim().isEmpty || price == null) return;
      final repo = ref.read(posRepositoryProvider);
      if (existing == null) {
        await repo.addProduct(Product(
            categoryId: selectedCategoryId!,
            name: nameCtrl.text.trim(),
            price: price));
      } else {
        await repo.updateProduct(Product(
            id: existing.id,
            categoryId: existing.categoryId,
            name: nameCtrl.text.trim(),
            price: price));
      }
      ref.invalidate(productsProvider(selectedCategoryId));
      ref.invalidate(productsProvider(null));
      Navigator.pop(ctx);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(existing == null ? 'Add Product' : 'Edit Product'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: Colors.white54)),
                  onSubmitted: (_) => priceFocus.requestFocus()),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                focusNode: priceFocus,
                style: const TextStyle(color: Colors.white),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                ],
                decoration: const InputDecoration(
                    labelText: 'Price (ETB)',
                    labelStyle: TextStyle(color: Colors.white54)),
                onSubmitted: (_) => doSave(ctx),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black),
            onPressed: () => doSave(ctx),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(int id) async {
    await ref.read(posRepositoryProvider).deleteCategory(id);
    ref.invalidate(categoriesProvider);
    ref.invalidate(productsProvider(null));
    if (selectedCategoryId == id) setState(() => selectedCategoryId = null);
  }

  void _deleteProduct(int id) async {
    await ref.read(posRepositoryProvider).deleteProduct(id);
    ref.invalidate(productsProvider(selectedCategoryId));
    ref.invalidate(productsProvider(null));
  }
}

// ── Waiter Management ─────────────────────────────────────────────────────

class WaiterManagementScreen extends ConsumerWidget {
  const WaiterManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waitersAsync = ref.watch(waitersProvider);
    return GlassContainer(
      opacity: 0.05,
      child: Column(
        children: [
          _Header(
              title: 'Waiters',
              onAdd: () => _showAddWaiterDialog(context, ref)),
          Expanded(
            child: waitersAsync.when(
              data: (waiters) => ListView.builder(
                itemCount: waiters.length,
                itemBuilder: (_, i) {
                  final w = waiters[i];
                  return ListTile(
                    leading: const CircleAvatar(
                        backgroundColor: Color(0xFFD4AF37),
                        child: Icon(Icons.person, color: Colors.black)),
                    title: Text(w.name),
                    subtitle: Text('Code: ${w.code}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      onPressed: () async {
                        await ref
                            .read(posRepositoryProvider)
                            .deleteWaiter(w.id!);
                        ref.refresh(waitersProvider);
                      },
                    ),
                  );
                },
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddWaiterDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();

    Future<void> doAdd(BuildContext ctx) async {
      if (ctrl.text.trim().isEmpty) return;
      await ref.read(posRepositoryProvider).addWaiter(ctrl.text.trim());
      ref.refresh(waitersProvider);
      Navigator.pop(ctx);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Add Waiter'),
        content: TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
                labelText: 'Waiter Name',
                labelStyle: TextStyle(color: Colors.white54)),
            onSubmitted: (_) => doAdd(ctx)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black),
            onPressed: () => doAdd(ctx),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ── Order History ─────────────────────────────────────────────────────────

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    final filter = ref.watch(reportDateFilterProvider);

    return GlassContainer(
      opacity: 0.05,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text('Order History',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const Spacer(),
                _DateFilterChips(filter: filter, onChanged: (f) {
                  ref.read(reportDateFilterProvider.notifier).set(f);
                }),
              ],
            ),
          ),
          Expanded(
            child: orders.when(
              data: (list) => list.isEmpty
                  ? const Center(
                      child: Opacity(
                          opacity: 0.4, child: Text('No orders in range')))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final o = list[i];
                        final settings =
                            ref.watch(appSettingsProvider).value ?? {};
                        final scPercent = double.tryParse(
                                settings['service_charge_percent'] ?? '5') ??
                            5;
                        return ExpansionTile(
                          title: Text('Order #${o.id} — ${o.tableName}'),
                          subtitle: Text(
                              'Waiter: ${o.waiterName}  |  Cashier: ${o.cashierName}  |  ${DateFormat('dd/MM HH:mm').format(o.createdAt)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                  '${o.grandTotal.toStringAsFixed(2)} ETB',
                                  style: const TextStyle(
                                      color: Color(0xFFD4AF37),
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              if (o.status == OrderStatus.completed)
                                 IconButton(
                                  icon: const Icon(Icons.print_outlined,
                                      size: 20, color: Colors.white54),
                                  tooltip: 'Reprint bill',
                                  onPressed: () async {
                                    final settings = await ref.read(cafeSettingsProvider.future);
                                    BillService.generateAndDownloadBill(
                                      order: o,
                                      items: o.items,
                                      settings: settings,
                                      cashierName: o.cashierName,
                                      serviceChargePercent: scPercent,
                                    );
                                  },
                                ),
                            ],
                          ),
                          children: o.items
                              .map((item) => ListTile(
                                    dense: true,
                                    title: Text(item.productName),
                                    subtitle: item.notes != null &&
                                            item.notes!.isNotEmpty
                                        ? Text(item.notes!,
                                            style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11))
                                        : null,
                                    trailing: Text(
                                        '${item.quantity} × ${item.unitPrice.toStringAsFixed(2)}'),
                                  ))
                              .toList(),
                        );
                      },
                    ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reports ───────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    final filter = ref.watch(reportDateFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date filter bar
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              const Text('Reports',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const Spacer(),
              _DateFilterChips(
                  filter: filter,
                  onChanged: (f) =>
                      ref.read(reportDateFilterProvider.notifier).set(f)),
            ],
          ),
        ),
        Expanded(
          child: orders.when(
            data: (orderList) {
              final completed =
                  orderList.where((o) => o.status == OrderStatus.completed).toList();
              final subtotalSum =
                  completed.fold(0.0, (s, o) => s + o.totalAmount);
              final serviceSum =
                  completed.fold(0.0, (s, o) => s + o.serviceCharge);
              final discountSum =
                  completed.fold(0.0, (s, o) => s + o.discountAmount);
              final grandSum =
                  completed.fold(0.0, (s, o) => s + o.grandTotal);
              final itemsSum = completed.fold(
                  0,
                  (s, o) =>
                      s + o.items.fold(0, (ss, i) => ss + i.quantity));

              // Per-waiter
              final waiterMap = <String, double>{};
              for (final o in completed) {
                waiterMap[o.waiterName] =
                    (waiterMap[o.waiterName] ?? 0) + o.grandTotal;
              }

              // Per-cashier
              final cashierMap = <String, double>{};
              for (final o in completed) {
                final name =
                    o.cashierName.isNotEmpty ? o.cashierName : 'Unknown';
                cashierMap[name] =
                    (cashierMap[name] ?? 0) + o.grandTotal;
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary cards
                    GridView.count(
                      crossAxisCount: 3,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 2.2,
                      children: [
                        _ReportCard(
                            title: 'Subtotal',
                            value: '${subtotalSum.toStringAsFixed(2)} ETB',
                            icon: Icons.receipt_outlined),
                        _ReportCard(
                            title: 'Service Charge',
                            value: '${serviceSum.toStringAsFixed(2)} ETB',
                            icon: Icons.room_service_outlined),
                        _ReportCard(
                            title: 'Discounts Given',
                            value: '${discountSum.toStringAsFixed(2)} ETB',
                            icon: Icons.discount_outlined),
                        _ReportCard(
                            title: 'Grand Total',
                            value: '${grandSum.toStringAsFixed(2)} ETB',
                            icon: Icons.trending_up,
                            color: const Color(0xFFD4AF37)),
                        _ReportCard(
                            title: 'Orders',
                            value: '${completed.length}',
                            icon: Icons.shopping_bag_outlined),
                        _ReportCard(
                            title: 'Items Sold',
                            value: '$itemsSum',
                            icon: Icons.fastfood_outlined),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // Per-waiter
                    if (waiterMap.isNotEmpty) ...[
                      const Text('By Waiter',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      GlassContainer(
                        opacity: 0.05,
                        child: Column(
                          children: waiterMap.entries
                              .map((e) => ListTile(
                                    leading: const CircleAvatar(
                                        backgroundColor: Color(0xFF006B3C),
                                        child: Icon(Icons.person,
                                            color: Colors.white, size: 18)),
                                    title: Text(e.key),
                                    trailing: Text(
                                        '${e.value.toStringAsFixed(2)} ETB',
                                        style: const TextStyle(
                                            color: Color(0xFFD4AF37),
                                            fontWeight: FontWeight.bold)),
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Per-cashier
                    if (cashierMap.isNotEmpty) ...[
                      const Text('By Cashier',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      GlassContainer(
                        opacity: 0.05,
                        child: Column(
                          children: cashierMap.entries
                              .map((e) => ListTile(
                                    leading: const CircleAvatar(
                                        backgroundColor: Color(0xFFD4AF37),
                                        child: Icon(Icons.point_of_sale,
                                            color: Colors.black, size: 18)),
                                    title: Text(e.key),
                                    trailing: Text(
                                        '${e.value.toStringAsFixed(2)} ETB',
                                        style: const TextStyle(
                                            color: Color(0xFFD4AF37),
                                            fontWeight: FontWeight.bold)),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
          ),
        ),
      ],
    );
  }
}

// ── Date filter chips ─────────────────────────────────────────────────────

class _DateFilterChips extends StatelessWidget {
  final DateFilter filter;
  final ValueChanged<DateFilter> onChanged;
  const _DateFilterChips({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    bool isToday = filter.from == todayStart && filter.to == todayEnd;
    bool isWeek = filter.from == weekStart && filter.to == todayEnd;
    bool isMonth = filter.from == monthStart && filter.to == todayEnd;
    bool isAll = filter.from == null && filter.to == null;

    return Row(
      children: [
        _chip('Today', isToday,
            () => onChanged(DateFilter(from: todayStart, to: todayEnd))),
        const SizedBox(width: 8),
        _chip('This Week', isWeek,
            () => onChanged(DateFilter(from: weekStart, to: todayEnd))),
        const SizedBox(width: 8),
        _chip('This Month', isMonth,
            () => onChanged(DateFilter(from: monthStart, to: todayEnd))),
        const SizedBox(width: 8),
        _chip('All Time', isAll,
            () => onChanged(const DateFilter())),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) =>
      ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: const Color(0xFFD4AF37),
        onSelected: (_) => onTap(),
      );
}

// ── Common components ─────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback? onAdd;
  const _Header({required this.title, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          if (onAdd != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add New'),
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black),
            ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  const _ReportCard(
      {required this.title,
      required this.value,
      required this.icon,
      this.color});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 36, color: color ?? Colors.white38),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: color ?? Colors.white),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Settings Screen ---
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _vatNumberController;
  late TextEditingController _vatRateController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _vatNumberController = TextEditingController();
    _vatRateController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _vatNumberController.dispose();
    _vatRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(cafeSettingsProvider);

    return settingsAsync.when(
      data: (settings) {
        _nameController.text = settings.name;
        _addressController.text = settings.address;
        _phoneController.text = settings.phone;
        _vatNumberController.text = settings.vatNumber;
        _vatRateController.text = settings.vatRate.toString();

        return GlassContainer(
          opacity: 0.05,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SYSTEM SETTINGS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2, color: Color(0xFFD4AF37))),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Cafe Information'),
                    _buildTextField('Cafe Name', _nameController),
                    _buildTextField('Address', _addressController),
                    _buildTextField('Phone Number', _phoneController),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Tax & Currency'),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('VAT Number', _vatNumberController)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildTextField('VAT Rate (%)', _vatRateController, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 48),
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            final newSettings = settings.copyWith(
                              name: _nameController.text,
                              address: _addressController.text,
                              phone: _phoneController.text,
                              vatNumber: _vatNumberController.text,
                              vatRate: double.tryParse(_vatRateController.text) ?? 5.0,
                            );
                            await ref.read(activeOrderServiceProvider).saveSettings(newSettings);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Settings saved successfully')),
                            );
                          }
                        },
                        child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.5)),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD4AF37))),
        ),
        validator: (value) => value == null || value.isEmpty ? 'Field required' : null,
      ),
    );
  }
}
