import 'package:flutter/material.dart'; // Reports Professionalization
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:st_george_pos/models/category.dart';
import 'package:st_george_pos/models/product.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/locales/app_localizations.dart';
import 'package:st_george_pos/services/bill_service.dart';
import 'package:st_george_pos/services/export_service.dart';
import 'package:st_george_pos/core/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/screens/order_screen.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:st_george_pos/models/charge.dart';
import 'package:st_george_pos/models/shift.dart';
import 'package:st_george_pos/models/z_report.dart';
import 'package:st_george_pos/screens/table_management_screen.dart';

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
    ref.watch(languageProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsProvider(selectedCategoryId));

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: GlassContainer(
            opacity: 0.05,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _Header(
                    title: ref.t('management.categories'),
                    onAdd: () => _showCategoryDialog(context, null),
                  ),
                  Expanded(
                    child: categoriesAsync.when(
                      data: (cats) => ListView.builder(
                        itemCount: cats.length,
                        itemBuilder: (_, i) {
                          final cat = cats[i];
                          return ListTile(
                            title: Text(
                              cat.name,
                              style: TextStyle(
                                color: selectedCategoryId == cat.id
                                    ? const Color(0xFFD4AF37)
                                    : Colors.white,
                                fontWeight: selectedCategoryId == cat.id
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: selectedCategoryId == cat.id,
                            onTap: () =>
                                setState(() => selectedCategoryId = cat.id),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              onPressed: () => _deleteCategory(cat.id!),
                            ),
                          );
                        },
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('${ref.t('common.error')}: $e'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: GlassContainer(
            opacity: 0.05,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Header(
                        title: ref.t('management.products'),
                        onAdd: selectedCategoryId == null
                            ? null
                            : () => _showProductDialog(context, null),
                      ),
                      if (selectedCategoryId != null)
                        TextButton.icon(
                          icon: const Icon(Icons.library_add_check, size: 18),
                          label: Text(ref.t('management.bulkAssign')),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFD4AF37),
                          ),
                          onPressed: () => _showBulkAssignDialog(
                            context,
                            selectedCategoryId!,
                          ),
                        ),
                    ],
                  ),
                  Expanded(
                    child: productsAsync.when(
                      data: (products) => ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (_, i) {
                          final p = products[i];
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              color: Colors.white10,
                              child: const Icon(
                                Icons.fastfood,
                                color: Color(0xFFD4AF37),
                              ),
                            ),
                            title: Text(p.name),
                            subtitle: Text(
                              '${p.price.toStringAsFixed(2)} ${ref.t('common.currency')}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _showProductDialog(context, p),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  onPressed: () => _deleteProduct(p.id!),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('${ref.t('common.error')}: $e'),
                    ),
                  ),
                ],
              ),
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
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          existing == null ? 'ADD CATEGORIES (Batch)' : ref.t('common.edit'),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: existing == null ? 5 : 1,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: existing == null
                ? 'Category Names (One per line)'
                : ref.t('management.name'),
            labelStyle: const TextStyle(color: Colors.white54),
            hintText: existing == null ? 'Coffee\nTea\nJuice' : null,
          ),
          onSubmitted: (_) => doSave(ctx),
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
              if (existing == null) {
                final names = ctrl.text
                    .split('\n')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty);
                for (final name in names) {
                  await ref.read(posRepositoryProvider).addCategory(name);
                }
              } else {
                // Update logic if needed (repo needs update for category edit)
                await ref
                    .read(posRepositoryProvider)
                    .addCategory(ctrl.text.trim());
              }
              ref.invalidate(categoriesProvider);
              Navigator.pop(ctx);
            },
            child: Text(ref.t('management.save')),
          ),
        ],
      ),
    );
  }

  void _showProductDialog(BuildContext context, Product? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.price.toString() : '',
    );
    final priceFocus = FocusNode();
    List<int> selectedIds =
        existing?.categoryIds ??
        (selectedCategoryId != null ? [selectedCategoryId!] : []);

    Future<void> doSave(BuildContext ctx) async {
      final price = double.tryParse(priceCtrl.text);
      if (nameCtrl.text.trim().isEmpty || price == null || selectedIds.isEmpty)
        return;
      final repo = ref.read(posRepositoryProvider);
      if (existing == null) {
        await repo.addProduct(
          Product(
            categoryIds: selectedIds,
            name: nameCtrl.text.trim(),
            price: price,
          ),
        );
      } else {
        await repo.updateProduct(
          Product(
            id: existing.id,
            categoryIds: selectedIds,
            name: nameCtrl.text.trim(),
            price: price,
          ),
        );
      }
      ref.invalidate(productsProvider(selectedCategoryId));
      ref.invalidate(productsProvider(null));
      Navigator.pop(ctx);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          existing == null
              ? ref.t('management.addProduct')
              : ref.t('common.edit'),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: ref.t('management.productName'),
                    labelStyle: const TextStyle(color: Colors.white54),
                  ),
                  onSubmitted: (_) => priceFocus.requestFocus(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  focusNode: priceFocus,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: InputDecoration(
                    labelText: ref.t(
                      'management.priceLabel',
                      replacements: {'currency': ref.t('common.currency')},
                    ),
                    labelStyle: const TextStyle(color: Colors.white54),
                  ),
                  onSubmitted: (_) => doSave(ctx),
                ),
                const SizedBox(height: 20),
                Text(
                  ref.t('management.categoriesLabel'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, _) {
                    final cats = ref.watch(categoriesProvider).value ?? [];
                    return Wrap(
                      spacing: 8,
                      children: cats
                          .map(
                            (c) => FilterChip(
                              label: Text(
                                c.name,
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: selectedIds.contains(c.id),
                              onSelected: (val) {
                                setDialogState(() {
                                  if (val)
                                    selectedIds.add(c.id!);
                                  else
                                    selectedIds.remove(c.id);
                                });
                              },
                            ),
                          )
                          .toList(),
                    );
                  },
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
            onPressed: () => doSave(ctx),
            child: Text(ref.t('management.save')),
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

  void _showBulkAssignDialog(BuildContext context, int categoryId) async {
    final allProducts = await ref.read(productsProvider(null).future);
    final categoryProducts = allProducts
        .where((p) => p.categoryIds.contains(categoryId))
        .map((e) => e.id!)
        .toSet();
    Set<int> selectedProductIds = Set.from(categoryProducts);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(ref.t('management.bulkAssignTitle')),
          content: SizedBox(
            width: 400,
            height: 400,
            child: ListView.builder(
              itemCount: allProducts.length,
              itemBuilder: (_, i) {
                final p = allProducts[i];
                final isSelected = selectedProductIds.contains(p.id!);
                return CheckboxListTile(
                  value: isSelected,
                  title: Text(
                    p.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  activeColor: const Color(0xFFD4AF37),
                  checkColor: Colors.black,
                  side: const BorderSide(color: Colors.white54),
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == true)
                        selectedProductIds.add(p.id!);
                      else
                        selectedProductIds.remove(p.id!);
                    });
                  },
                );
              },
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
                final repo = ref.read(posRepositoryProvider);
                for (final p in allProducts) {
                  final shouldBeInCategory = selectedProductIds.contains(p.id!);
                  final isInCategory = p.categoryIds.contains(categoryId);

                  if (shouldBeInCategory && !isInCategory) {
                    final newIds = List<int>.from(p.categoryIds)
                      ..add(categoryId);
                    await repo.updateProduct(p.copyWith(categoryIds: newIds));
                  } else if (!shouldBeInCategory && isInCategory) {
                    final newIds = List<int>.from(p.categoryIds)
                      ..remove(categoryId);
                    await repo.updateProduct(p.copyWith(categoryIds: newIds));
                  }
                }
                ref.invalidate(productsProvider(categoryId));
                ref.invalidate(productsProvider(null));
                if (mounted) Navigator.pop(ctx);
              },
              child: Text(ref.t('management.save')),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Waiter Management ─────────────────────────────────────────────────────

class WaiterManagementScreen extends ConsumerStatefulWidget {
  const WaiterManagementScreen({super.key});

  @override
  ConsumerState<WaiterManagementScreen> createState() =>
      _WaiterManagementScreenState();
}

class _WaiterManagementScreenState extends ConsumerState<WaiterManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFFD4AF37),
          tabs: [
            Tab(text: ref.t('management.waiters').toUpperCase()),
            Tab(text: ref.t('tables.tables').toUpperCase()),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildWaitersList(), const TableManagementScreen()],
          ),
        ),
      ],
    );
  }

  Widget _buildWaitersList() {
    final waitersAsync = ref.watch(waitersProvider);
    return GlassContainer(
      opacity: 0.05,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _Header(
              title: ref.t('management.waiters'),
              onAdd: () => _showAddWaiterDialog(context, ref),
            ),
            Expanded(
              child: waitersAsync.when(
                data: (waiters) => ListView.builder(
                  itemCount: waiters.length,
                  itemBuilder: (_, i) {
                    final w = waiters[i];
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        color: const Color(0xFFD4AF37),
                        child: const Icon(Icons.person, color: Colors.black),
                      ),
                      title: Text(w.name),
                      subtitle: Text('${ref.t('management.code')}: ${w.code}'),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
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
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('${ref.t('common.error')}: $e'),
              ),
            ),
          ],
        ),
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
        title: Text(ref.t('management.addWaiter')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: ref.t('management.waiterNameLabel'),
            labelStyle: const TextStyle(color: Colors.white54),
          ),
          onSubmitted: (_) => doAdd(ctx),
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
            onPressed: () => doAdd(ctx),
            child: Text(ref.t('management.add')),
          ),
        ],
      ),
    );
  }
}

// ── Order History ─────────────────────────────────────────────────────────

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});
  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  String searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final ordersAsync = ref.watch(ordersProvider);
    final filter = ref.watch(reportDateFilterProvider);

    return GlassContainer(
      opacity: 0.05,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  ref.t('management.orders'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 24),
                // Waiter Search Bar
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => searchQuery = v),
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: ref.t('history.searchByWaiter'),
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 16,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                _DateFilterChips(
                  filter: filter,
                  onChanged: (f) {
                    ref.read(reportDateFilterProvider.notifier).set(f);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              data: (list) {
                final filtered = list
                    .where(
                      (o) => o.waiterName.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ),
                    )
                    .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Opacity(
                      opacity: 0.4,
                      child: Text(
                        searchQuery.isEmpty
                            ? ref.t('management.noOrdersInRange')
                            : 'No matching orders for this waiter',
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final o = filtered[i];
                    return ExpansionTile(
                      title: Text(
                        ref.t(
                          'management.order',
                          replacements: {'id': '${o.id}', 'table': o.tableName},
                        ),
                      ),
                      subtitle: Text(
                        '${ref.t('bill.waiter')}: ${o.waiterName}  |  ${ref.t('bill.cashier')}: ${o.cashierName}  |  ${DateFormat('dd/MM HH:mm').format(o.createdAt)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${o.grandTotal.toStringAsFixed(2)} ${ref.t('common.currency')}',
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (o.status == OrderStatus.completed)
                            IconButton(
                              icon: const Icon(
                                Icons.print_outlined,
                                size: 20,
                                color: Colors.white54,
                              ),
                              tooltip: ref.t('management.reprintBill'),
                              onPressed: () async {
                                final appSettings = await ref.read(
                                  appSettingsProvider.future,
                                );
                                final printerName =
                                    appSettings['default_printer_name'];
                                final settings = await ref.read(
                                  cafeSettingsProvider.future,
                                );
                                final charges = (await ref.read(
                                  chargesProvider.future,
                                )).where((c) => c.isActive).toList();
                                await BillService.generateAndDownloadBill(
                                  order: o,
                                  items: o.items,
                                  settings: settings,
                                  cashierName: o.cashierName,
                                  activeCharges: charges,
                                  printerName: printerName,
                                );
                              },
                            ),
                        ],
                      ),
                      children: o.items
                          .map(
                            (item) => ListTile(
                              dense: true,
                              title: Text(item.productName),
                              subtitle:
                                  item.notes != null && item.notes!.isNotEmpty
                                  ? Text(
                                      item.notes!,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    )
                                  : null,
                              trailing: Text(
                                '${item.quantity} × ${item.unitPrice.toStringAsFixed(2)}',
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Held Orders (Pending Invoices) ────────────────────────────────────────

class HeldOrdersScreen extends ConsumerStatefulWidget {
  const HeldOrdersScreen({super.key});

  @override
  ConsumerState<HeldOrdersScreen> createState() => _HeldOrdersScreenState();
}

class _HeldOrdersScreenState extends ConsumerState<HeldOrdersScreen> {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);

    return GlassContainer(
      opacity: 0.05,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(
                  Icons.pause_circle_outline,
                  color: Color(0xFFD4AF37),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  ref.t('held.title'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 24),
                // Search Bar
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.toLowerCase()),
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: ref.t('management.searchOrdersHint'),
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 16,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              data: (list) {
                final pending = list
                    .where((o) => o.status == OrderStatus.pending)
                    .where((o) {
                      if (_searchQuery.isEmpty) return true;
                      final matchesWaiter = o.waiterName.toLowerCase().contains(
                        _searchQuery,
                      );
                      final matchesTable = o.tableName.toLowerCase().contains(
                        _searchQuery,
                      );
                      final matchesItem = o.items.any(
                        (it) =>
                            it.productName.toLowerCase().contains(_searchQuery),
                      );
                      return matchesWaiter || matchesTable || matchesItem;
                    })
                    .toList();

                if (pending.isEmpty) {
                  return Center(
                    child: Opacity(
                      opacity: 0.4,
                      child: Text(
                        _searchQuery.isEmpty
                            ? ref.t('held.noHeldOrders')
                            : 'No matching orders found',
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: pending.length,
                  itemBuilder: (_, i) {
                    final o = pending[i];

                    // Find matched item if searching by product
                    OrderItem? matchedItem;
                    if (_searchQuery.isNotEmpty) {
                      try {
                        matchedItem = o.items.firstWhere(
                          (it) => it.productName.toLowerCase().contains(
                            _searchQuery,
                          ),
                        );
                      } catch (_) {}
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.white.withOpacity(0.05),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      child: ListTile(
                        onTap: () {
                          // Jump to the table order screen
                          final table = TableModel(
                            id: o.tableId,
                            name: o.tableName,
                            status: TableStatus.occupied,
                          );
                          ref.read(selectedTableProvider.notifier).set(table);
                          ref.read(dashboardViewProvider.notifier).state =
                              DashboardView.pos;
                        },
                        title: Row(
                          children: [
                            Text(
                              ref.t(
                                'management.order',
                                replacements: {
                                  'id': '${o.id}',
                                  'table': o.tableName,
                                },
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (matchedItem != null) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                color: const Color(
                                  0xFFD4AF37,
                                ).withOpacity(0.15),
                                child: Text(
                                  '${matchedItem.productName} ×${matchedItem.quantity}',
                                  style: const TextStyle(
                                    color: Color(0xFFD4AF37),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${ref.t('bill.waiter')}: ${o.waiterName}  |  ${ref.t('order.items')}: ${o.items.length}  |  ${ref.t('held.started')}: ${DateFormat('HH:mm').format(o.createdAt)}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${o.totalAmount.toStringAsFixed(2)} ${ref.t('common.currency')}',
                              style: const TextStyle(
                                color: Color(0xFFD4AF37),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              ref.t('held.tapToOpen'),
                              style: const TextStyle(
                                color: Colors.white24,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shift Management ───────────────────────────────────────────────────────

class ShiftManagementScreen extends ConsumerWidget {
  const ShiftManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentShift = ref.watch(currentShiftProvider);
    final user = ref.watch(authProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            ref.t('shift.title'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: currentShift.when(
            data: (shift) {
              if (shift == null) {
                return _buildNoActiveShift(context, ref);
              }
              return _buildActiveShift(context, ref, shift);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                ref.t(
                  'errors.errorWithMessage',
                  replacements: {'message': '$e'},
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoActiveShift(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.no_accounts_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 24),
          Text(
            ref.t('shift.noActive'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ref.t('shift.openNewDescription'),
            style: TextStyle(color: Colors.white38),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            icon: const Icon(Icons.play_arrow),
            label: Text(
              ref.t('shift.openNew'),
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            onPressed: () => _showOpenShiftDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveShift(
    BuildContext context,
    WidgetRef ref,
    ShiftModel shift,
  ) {
    final startTime = DateFormat('MMM d, HH:mm').format(shift.startTime);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassContainer(
            opacity: 0.05,
            padding: const EdgeInsets.all(32),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Text(
                              ref.t('shift.active'),
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            ref.t(
                              'shift.shiftNumber',
                              replacements: {'id': '${shift.id}'},
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white38,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        shift.cashierName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ref.t(
                          'shift.startedOn',
                          replacements: {'time': startTime},
                        ),
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      ref.t('shift.startCash'),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white38,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${shift.startingCash.toStringAsFixed(2)} ETB',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: _ShiftActionCard(
                  title: ref.t('shift.xReport'),
                  subtitle: ref.t('shift.xReportSubtitle'),
                  icon: Icons.receipt_long,
                  color: Colors.blueAccent,
                  onTap: () => _printXReport(context, ref, shift),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _ShiftActionCard(
                  title: ref.t('shift.endShiftZ'),
                  subtitle: ref.t('shift.endShiftSubtitle'),
                  icon: Icons.power_settings_new,
                  color: Colors.redAccent,
                  onTap: () => _showEndShiftDialog(context, ref, shift),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showOpenShiftDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: '0.00');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(ref.t('shift.openNew')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ref.t('shift.openNewDescription'),
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: ref.t('shift.startingCash'),
                prefixText: '${ref.t('common.currency')} ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.t('common.cancel').toUpperCase()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final cash = double.tryParse(controller.text) ?? 0.0;
              await ref.read(activeOrderServiceProvider).startShift(cash);
              Navigator.pop(ctx);
            },
            child: Text(ref.t('shift.openShift')),
          ),
        ],
      ),
    );
  }

  void _showEndShiftDialog(
    BuildContext context,
    WidgetRef ref,
    ShiftModel shift,
  ) async {
    final reportData = await ref
        .read(posRepositoryProvider)
        .getShiftReportData(shift.id!);
    final cashSales =
        (reportData['payment_methods'] as Map<String, dynamic>)['cash'] ?? 0.0;
    final expectedCash = shift.startingCash + cashSales;

    final controller = TextEditingController();

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final declared = double.tryParse(controller.text) ?? 0.0;
          final diff = declared - expectedCash;

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Text(ref.t('shift.endReconcile')),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _reconcileRow(
                          ref.t('shift.startCash'),
                          shift.startingCash,
                        ),
                        _reconcileRow(ref.t('shift.cashSales'), cashSales),
                        const Divider(color: Colors.white10),
                        _reconcileRow(
                          ref.t('shift.expectedDrawer'),
                          expectedCash,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: ref.t('shift.actualCashCounted'),
                      prefixText: 'ETB ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (controller.text.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: diff == 0
                            ? Colors.green.withOpacity(0.1)
                            : (diff > 0
                                  ? Colors.blue.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            diff == 0
                                ? ref.t('shift.balanced')
                                : (diff > 0
                                      ? ref.t('shift.overage')
                                      : ref.t('shift.shortage')),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: diff == 0
                                  ? Colors.green
                                  : (diff > 0 ? Colors.blue : Colors.red),
                            ),
                          ),
                          Text(
                            '${diff > 0 ? "+" : ""}${diff.toStringAsFixed(2)} ETB',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: diff == 0
                                  ? Colors.green
                                  : (diff > 0 ? Colors.blue : Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ref.t('common.cancel').toUpperCase()),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final cash = double.tryParse(controller.text) ?? 0.0;

                  // 1. Generate Report Data Snapshot
                  final reportData = await ref
                      .read(posRepositoryProvider)
                      .getShiftReportData(shift.id!);

                  // 2. Inject actual cash declared into the snapshot
                  final cashRec =
                      reportData['cash_reconciliation'] as Map<String, dynamic>;
                  cashRec['actual_counted'] = cash;
                  cashRec['difference'] =
                      cash - (cashRec['expected_cash'] as num);

                  // 3. Save Z-Report to Database
                  await ref
                      .read(posRepositoryProvider)
                      .createZReport(shift.id!, reportData);

                  // 4. End the shift in DB
                  await ref
                      .read(activeOrderServiceProvider)
                      .endShift(shift.id!, cash);

                  // 5. Print the Z-Slip
                  final settings = await ref
                      .read(posRepositoryProvider)
                      .getCafeSettings();
                  await BillService.printReport(
                    reportData: reportData,
                    settings: settings,
                    isZReport: true,
                  );

                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ref.t('shift.zReportSaved')),
                    ),
                  );
                },
                child: Text(ref.t('shift.closeShift')),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _reconcileRow(String label, double value, {bool isBold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isBold ? Colors.white : Colors.white54,
                fontSize: 13,
              ),
            ),
            Text(
              '${value.toStringAsFixed(2)} ETB',
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isBold ? const Color(0xFFD4AF37) : Colors.white,
              ),
            ),
          ],
        ),
      );

  void _printXReport(
    BuildContext context,
    WidgetRef ref,
    ShiftModel shift,
  ) async {
    final reportData = await ref
        .read(posRepositoryProvider)
        .getShiftReportData(shift.id!);
    final settings = await ref.read(posRepositoryProvider).getCafeSettings();

    await BillService.printReport(
      reportData: reportData,
      settings: settings,
      isZReport: false,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ref.t('shift.xReportSent'))));
  }
}

class _ShiftActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ShiftActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: GlassContainer(
        opacity: 0.03,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reports ───────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _showDetailView = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final orders = ref.watch(ordersProvider);
    final filter = ref.watch(reportDateFilterProvider);
    final selectedWaiterId = ref.watch(reportWaiterFilterProvider);
    final waitersAsync = ref.watch(waitersProvider);

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                Text(
                  ref.t('management.reports'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 24),
                // TabBar
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TabBar(
                    isScrollable: true,
                    indicator: BoxDecoration(
                      color: const Color(0xFFD4AF37),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    tabs: [
                      Tab(text: ref.t('reports.liveSummary').toUpperCase()),
                      Tab(text: ref.t('reports.shiftArchive').toUpperCase()),
                    ],
                  ),
                ),
                const Spacer(),
                // Waiter Filter (Keep for X-Report context if needed)
                if (waitersAsync.hasValue)
                  Container(
                    width: 180,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: selectedWaiterId,
                        hint: Text(
                          ref.t('navigation.waiters'),
                          style: const TextStyle(fontSize: 13, color: Colors.white54),
                        ),
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1A1A1A),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Waiters'),
                          ),
                          ...waitersAsync.value!.map(
                            (w) => DropdownMenuItem(
                              value: w.id,
                              child: Text(w.name),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            ref.read(reportWaiterFilterProvider.notifier).set(v),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildXReportTab(context, ref, orders, selectedWaiterId),
                _buildZReportTab(context, ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXReportTab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<OrderModel>> ordersAsync,
    int? waiterId,
  ) {
    return ordersAsync.when(
      data: (list) {
        final completed = list
            .where((o) => o.status == OrderStatus.completed)
            .where((o) => waiterId == null || o.waiterId == waiterId)
            .toList();

        final subtotalSum = completed.fold(0.0, (s, o) => s + o.totalAmount);
        final serviceSum = completed.fold(0.0, (s, o) => s + o.serviceCharge);
        final discountSum = completed.fold(0.0, (s, o) => s + o.discountAmount);
        final grandTotalSum = completed.fold(0.0, (s, o) => s + o.grandTotal);

        final categoryMap = <String, double>{};
        final paymentMap = <String, double>{};
        final orderTypeMap = {
          'Dine-in': 0.0,
          'Takeaway': 0.0,
          'Delivery': 0.0,
        };

        for (final o in completed) {
          paymentMap[o.paymentMethod] =
              (paymentMap[o.paymentMethod] ?? 0) + o.grandTotal;

          final tName = o.tableName.toLowerCase();
          if (tName.contains('takeaway')) {
            orderTypeMap['Takeaway'] = orderTypeMap['Takeaway']! + o.grandTotal;
          } else if (tName.contains('delivery')) {
            orderTypeMap['Delivery'] = orderTypeMap['Delivery']! + o.grandTotal;
          } else {
            orderTypeMap['Dine-in'] = orderTypeMap['Dine-in']! + o.grandTotal;
          }

          for (final item in o.items) {
            final catName = item.categoryName ?? "General";
            categoryMap[catName] = (categoryMap[catName] ?? 0) + item.subtotal;
          }
        }

        // Waiters, Cashiers, Best Sellers aggregations...
        final waiterMap = <String, double>{};
        for (final o in completed) {
          waiterMap[o.waiterName] = (waiterMap[o.waiterName] ?? 0) + o.grandTotal;
        }

        final itemSalesMap = <String, Map<String, dynamic>>{};
        for (final o in completed) {
          for (final item in o.items) {
            if (!itemSalesMap.containsKey(item.productName)) {
              itemSalesMap[item.productName] = {'qty': 0, 'revenue': 0.0};
            }
            itemSalesMap[item.productName]!['qty'] += item.quantity;
            itemSalesMap[item.productName]!['revenue'] += item.subtotal;
          }
        }
        final sortedItemSales = itemSalesMap.entries.toList()
          ..sort(
            (a, b) => (b.value['revenue'] as double).compareTo(
              a.value['revenue'] as double,
            ),
          );

        final cashierMap = <String, double>{};
        for (final o in completed) {
          final name = o.cashierName.isNotEmpty
              ? o.cashierName
              : ref.t('management.unknown');
          cashierMap[name] = (cashierMap[name] ?? 0) + o.grandTotal;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // X-Report Header Bar (Gold/Yellow)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFD4AF37).withOpacity(0.15),
                      const Color(0xFFD4AF37).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    // Pulse Icon
                    FadeTransition(
                      opacity: _pulseController,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD4AF37),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFD4AF37),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      ref.t('reports.currentShiftX'),
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ref.t('reports.livePulse'),
                        style: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.print, size: 18),
                      label: Text(ref.t('reports.printXReport')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: () => _printFilteredReport(
                        context,
                        ref,
                        list,
                        ref.read(reportDateFilterProvider),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _ReportMetricTile(
                    label: ref.t('management.subtotal'),
                    value: subtotalSum,
                  ),
                  _ReportMetricTile(
                    label: ref.t('management.serviceCharge'),
                    value: serviceSum,
                  ),
                  _ReportMetricTile(
                    label: ref.t('management.discountsGiven'),
                    value: -discountSum,
                    color: Colors.redAccent,
                  ),
                  _ReportMetricTile(
                    label: ref.t('management.grandTotal'),
                    value: grandTotalSum,
                    isGrand: true,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── Category Breakdown ───────────────────────────────
              _SectionHeader(ref.t('reports.salesByCategory').toUpperCase()),
              const SizedBox(height: 16),
              _CategoryBreakdownDashboard(categoryMap: categoryMap),
              const SizedBox(height: 32),

              // ── Order Type Breakdown ─────────────────────────────
              _SectionHeader('ORDER TYPE DISTRIBUTION'),
              const SizedBox(height: 16),
              _OrderTypeDashboard(orderTypeMap: orderTypeMap),
              const SizedBox(height: 32),

              // ── Best Sellers Visualization ──────────────────────
              _SectionHeader(ref.t('reports.bestSellers').toUpperCase()),
              const SizedBox(height: 16),
              _BestSellersDashboard(sortedItemSales: sortedItemSales),
              const SizedBox(height: 32),

              // ── Detailed Breakdowns ─────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader('PAYMENT BREAKDOWN'),
                        const SizedBox(height: 12),
                        _FormalDataTable(
                          data: paymentMap.entries.toList(),
                          icon: Icons.payments_outlined,
                          iconColor: Colors.greenAccent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(ref.t('management.byWaiter')),
                        const SizedBox(height: 12),
                        _FormalDataTable(
                          data: waiterMap.entries.toList(),
                          icon: Icons.person_outline,
                          iconColor: const Color(0xFF006B3C),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              if (_showDetailView) _buildDetailView(completed),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('${ref.t('common.error')}: $e'),
    );
  }

  Widget _buildZReportTab(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(zReportsProvider);
    String _fmt(double v) => v.toStringAsFixed(2);

    return Column(
      children: [
        // Z-Report Archive Header (Grey/Green)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10, bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              const Icon(Icons.archive_outlined, color: Colors.white54, size: 20),
              const SizedBox(width: 12),
              Text(
                ref.t('reports.archiveZ'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: reportsAsync.when(
            data: (reports) {
              if (reports.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_toggle_off,
                          size: 64, color: Colors.white10),
                      const SizedBox(height: 16),
                      Text(
                        ref.t('reports.noArchive'),
                        style: const TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: reports.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final report = reports[index];
                  final total = report.reportData['financials']?['grand_total'] ?? 0.0;
                  final cashier = report.reportData['shift_info']?['cashier_name'] ?? 'Unknown';
                  final date = DateFormat('MMM dd, yyyy HH:mm').format(report.createdAt);

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ref.t('reports.shiftId', replacements: {'id': report.zCount.toString()}),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                date,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                                ref.t('reports.total', replacements: {'amount': _fmt(total)}),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ref.t('reports.closedBy', replacements: {'name': cashier}),
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.print_outlined, size: 16),
                          label: Text(ref.t('reports.reprintZReport')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onPressed: () async {
                            final settings = await ref.read(posRepositoryProvider).getCafeSettings();
                            await BillService.reprintZReport(
                              report: report,
                              settings: settings,
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFD4AF37) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: active ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailView(List<OrderModel> completed) {
    if (completed.isEmpty) {
      return Center(
        child: Opacity(
          opacity: 0.4,
          child: Text(ref.t('management.noOrdersInRange')),
        ),
      );
    }

    final waiterGroups = <String, List<OrderModel>>{};
    for (final o in completed) {
      waiterGroups.putIfAbsent(o.waiterName, () => []).add(o);
    }

    return ListView(
      children: waiterGroups.entries.map((entry) {
        final waiterTotal = entry.value.fold<double>(
          0,
          (s, o) => s + o.grandTotal,
        );
        final orderCount = entry.value.length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: GlassContainer(
            opacity: 0.05,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 20,
                      color: Color(0xFFD4AF37),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.key.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$orderCount orders',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${waiterTotal.toStringAsFixed(2)} ETB',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Colors.white10),
                const SizedBox(height: 8),
                ...entry.value.map(
                  (o) => ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    childrenPadding: const EdgeInsets.only(left: 16, bottom: 8),
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          color: const Color(0xFFD4AF37).withOpacity(0.15),
                          child: Text(
                            '#${o.id}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD4AF37),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${o.tableName}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('dd/MM HH:mm').format(o.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${o.grandTotal.toStringAsFixed(2)} ETB',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD4AF37),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                'Item',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.4),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              child: Text(
                                'Qty',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.4),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                'Price',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.4),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text(
                                'Total',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.4),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...o.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  item.productName,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              SizedBox(
                                width: 40,
                                child: Text(
                                  '${item.quantity}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  item.unitPrice.toStringAsFixed(2),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  item.subtotal.toStringAsFixed(2),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 16, color: Colors.white10),
                      Row(
                        children: [
                          const Spacer(),
                          Text(
                            'Subtotal: ${o.totalAmount.toStringAsFixed(2)}  |  SC: ${o.serviceCharge.toStringAsFixed(2)}  |  Disc: -${o.discountAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Spacer(),
                          Text(
                            'Order Total: ${o.grandTotal.toStringAsFixed(2)} ETB',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD4AF37),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _printFilteredReport(
    BuildContext context,
    WidgetRef ref,
    List<OrderModel> allOrders,
    DateFilter filter,
  ) async {
    final selectedWaiterId = ref.read(reportWaiterFilterProvider);
    final completed = allOrders
        .where((o) => o.status == OrderStatus.completed)
        .where(
          (o) => selectedWaiterId == null || o.waiterId == selectedWaiterId,
        )
        .toList();

    if (completed.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ref.t('reports.noOrdersToPrint'))));
      return;
    }

    final settings = await ref.read(posRepositoryProvider).getCafeSettings();

    // We use a dummy shift ID (-1) to signal a generic date-range report
    final reportData = await ref
        .read(posRepositoryProvider)
        .getShiftReportData(-1);

    // Overwrite times with filter range
    final header = reportData['report_header'] as Map<String, dynamic>;
    header['opening_time'] =
        filter.from?.toIso8601String() ??
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    header['closing_time'] =
        filter.to?.toIso8601String() ?? DateTime.now().toIso8601String();
    header['report_type'] = 'X REPORT (FILTERED)';

    // Inject real filtered orders into report data for detailed printing
    reportData['orders_detail'] = completed
        .map(
          (o) => {
            'id': o.id,
            'table_name': o.tableName,
            'waiter_name': o.waiterName,
            'waiter_id': o.waiterId,
            'cashier_name': o.cashierName,
            'created_at': o.createdAt.toIso8601String(),
            'total_amount': o.totalAmount,
            'service_charge': o.serviceCharge,
            'discount_amount': o.discountAmount,
            'grand_total': o.grandTotal,
            'items': o.items
                .map(
                  (i) => {
                    'product_name': i.productName,
                    'quantity': i.quantity,
                    'unit_price': i.unitPrice,
                    'subtotal': i.subtotal,
                  },
                )
                .toList(),
          },
        )
        .toList();

    await BillService.printReport(
      reportData: reportData,
      settings: settings,
      isZReport: false,
    );
  }
}

class _ZReportHistorySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(zReportsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        reports.when(
          data: (list) {
            if (list.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    'No Z-Reports archived.',
                    style: TextStyle(color: Colors.white24),
                  ),
                ),
              );
            }
            return SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final r = list[index];
                  final header =
                      r.reportData['report_header'] as Map<String, dynamic>;
                  final cashRec =
                      r.reportData['cash_reconciliation']
                          as Map<String, dynamic>?;
                  final variance = (cashRec?['difference'] as num? ?? 0.0);

                  return Container(
                    width: 320,
                    margin: const EdgeInsets.only(right: 16),
                    child: GlassContainer(
                      opacity: 0.05,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Z-REPORT #${r.zCount}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Color(0xFFD4AF37),
                                ),
                              ),
                              _VarianceBadge(variance: variance),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            header['cashier_name']?.toString().toUpperCase() ??
                                'UNKNOWN',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),

                          Text(
                            DateFormat('MMM d, HH:mm').format(r.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),

                          const Divider(height: 24, color: Colors.white10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ref.t('shift.netSales'),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.white38,
                                    ),
                                  ),
                                  Text(
                                    '${(r.reportData['sales_totals']?['net_sales'] as num? ?? 0).toStringAsFixed(2)} ${ref.t('common.currency')}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _showZReportDetail(context, ref, r),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.print_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      final settings = await ref
                                          .read(posRepositoryProvider)
                                          .getCafeSettings();
                                      await BillService.printReport(
                                        reportData: r.reportData,
                                        settings: settings,
                                        isZReport: true,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(
            ref.t('errors.errorWithMessage', replacements: {'message': '$e'}),
          ),
        ),
      ],
    );
  }

  void _showZReportDetail(
    BuildContext context,
    WidgetRef ref,
    ZReportModel report,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 350,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Icon(
                  Icons.receipt_long,
                  color: Color(0xFFD4AF37),
                  size: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  ref.t('reports.digitalZReport'),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const Divider(height: 32, color: Colors.white10),
                _DigitalSlipRow(
                  ref.t('reports.reportNumber'),
                  '${report.zCount}',
                ),
                _DigitalSlipRow(
                  ref.t('bill.cashier'),
                  report.reportData['report_header']['cashier_name'],
                ),
                _DigitalSlipRow(
                  ref.t('bill.date'),
                  DateFormat('dd/MM/yyyy').format(report.createdAt),
                ),
                const Divider(height: 32, color: Colors.white10),
                _DigitalSlipRow(
                  ref.t('reports.grossSales'),
                  '${report.reportData['sales_totals']['gross_sales']}',
                ),
                if ((report.reportData['sales_totals']['vat'] as num? ?? 0) > 0)
                  _DigitalSlipRow(
                    ref.t('reports.vat'),
                    '${report.reportData['sales_totals']['vat']}',
                  ),
                _DigitalSlipRow(
                  ref.t('bill.discount'),
                  '${report.reportData['sales_totals']['discounts']}',
                ),
                _DigitalSlipRow(
                  ref.t('reports.netTotal'),
                  '${report.reportData['sales_totals']['net_sales']}',
                  isBold: true,
                ),

                const Divider(height: 32, color: Colors.white10),
                Text(
                  ref.t('reports.paymentMethods'),
                  style: TextStyle(fontSize: 10, color: Colors.white38),
                ),
                const SizedBox(height: 8),
                ...(report.reportData['payment_methods']
                        as Map<String, dynamic>)
                    .entries
                    .map(
                      (e) => _DigitalSlipRow(e.key.toUpperCase(), '${e.value}'),
                    ),
                const Divider(height: 32, color: Colors.white10),
                _DigitalSlipRow(
                  ref.t('shift.cashVariance'),
                  '${report.reportData['cash_reconciliation']['difference']}',
                  isBold: true,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                  ),
                  child: Text(ref.t('shift.closePreview')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DigitalSlipRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  const _DigitalSlipRow(this.label, this.value, {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? const Color(0xFFD4AF37) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _VarianceBadge extends StatelessWidget {
  final num variance;
  const _VarianceBadge({required this.variance});

  @override
  Widget build(BuildContext context) {
    final isBalanced = variance == 0;
    final isShort = variance < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isBalanced
            ? Colors.green.withOpacity(0.1)
            : (isShort
                  ? Colors.red.withOpacity(0.1)
                  : Colors.blue.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isBalanced ? 'BALANCED' : (isShort ? 'SHORTAGE' : 'OVERAGE'),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: isBalanced
              ? Colors.green
              : (isShort ? Colors.red : Colors.blue),
        ),
      ),
    );
  }
}

class _ReportMetricTile extends StatelessWidget {
  final String label;
  final double value;
  final Color? color;
  final bool isGrand;

  const _ReportMetricTile({
    required this.label,
    required this.value,
    this.color,
    this.isGrand = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: GlassContainer(
          opacity: isGrand ? 0.15 : 0.05,
          padding: const EdgeInsets.all(20), // Increased from 16
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.5),
                  letterSpacing: 1.2,
                ),
              ), // Increased font and opacity
              const SizedBox(height: 12),
              Text(
                '${value.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: isGrand ? 32 : 24, // Increased font size
                  fontWeight: FontWeight.w900,
                  color:
                      color ??
                      (isGrand ? const Color(0xFFD4AF37) : Colors.white),
                ),
              ),
              Text(
                'ETB',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      (color ??
                              (isGrand
                                  ? const Color(0xFFD4AF37)
                                  : Colors.white))
                          .withOpacity(0.4),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BestSellersDashboard extends StatelessWidget {
  final List<MapEntry<String, Map<String, dynamic>>> sortedItemSales;
  const _BestSellersDashboard({required this.sortedItemSales});

  @override
  Widget build(BuildContext context) {
    if (sortedItemSales.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No item sales to visualize.',
            style: TextStyle(color: Colors.white24),
          ),
        ),
      );
    }

    final maxRevenue = sortedItemSales.first.value['revenue'] as double;

    return GlassContainer(
      opacity: 0.05,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: sortedItemSales.take(10).map((entry) {
          final revenue = entry.value['revenue'] as double;
          final percentage = maxRevenue > 0 ? (revenue / maxRevenue) : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.key.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${revenue.toStringAsFixed(2)} ETB',
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          color: const Color(0xFFD4AF37).withOpacity(0.8),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'x${entry.value['qty']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CategoryBreakdownDashboard extends StatelessWidget {
  final Map<String, double> categoryMap;
  const _CategoryBreakdownDashboard({required this.categoryMap});

  @override
  Widget build(BuildContext context) {
    if (categoryMap.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No category data available.',
            style: TextStyle(color: Colors.white24),
          ),
        ),
      );
    }

    final total = categoryMap.values.fold(0.0, (s, v) => s + v);
    final sortedEntries = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return GlassContainer(
      opacity: 0.05,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: sortedEntries.map((entry) {
          final percentage = total > 0 ? (entry.value / total) : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    entry.key.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      color: const Color(0xFFD4AF37),
                      minHeight: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${entry.value.toStringAsFixed(2)} ETB',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFD4AF37),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OrderTypeDashboard extends StatelessWidget {
  final Map<String, double> orderTypeMap;
  const _OrderTypeDashboard({required this.orderTypeMap});

  @override
  Widget build(BuildContext context) {
    if (orderTypeMap.isEmpty || orderTypeMap.values.every((v) => v == 0)) {
      return const SizedBox.shrink();
    }

    final total = orderTypeMap.values.fold(0.0, (s, v) => s + v);

    return GlassContainer(
      opacity: 0.05,
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: orderTypeMap.entries.map((entry) {
          final percentage = total > 0 ? (entry.value / total) * 100 : 0.0;
          return Column(
            children: [
              Text(
                entry.key.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white38,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFD4AF37),
                ),
              ),
              Text(
                '${entry.value.toStringAsFixed(2)} ETB',
                style: const TextStyle(fontSize: 10, color: Colors.white54),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Date filter chips ─────────────────────────────────────────────────────

class _DateFilterChips extends ConsumerWidget {
  final DateFilter filter;
  final ValueChanged<DateFilter> onChanged;
  const _DateFilterChips({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final selectedType = ref.watch(reportDateTypeProvider);

    return Row(
      children: [
        _chip(ref.t('filters.today'), selectedType == DateFilterType.today, () {
          ref.read(reportDateTypeProvider.notifier).set(DateFilterType.today);
          onChanged(DateFilter(from: todayStart, to: todayEnd));
        }),
        const SizedBox(width: 8),
        _chip(
          ref.t('filters.thisWeek'),
          selectedType == DateFilterType.week,
          () {
            ref.read(reportDateTypeProvider.notifier).set(DateFilterType.week);
            onChanged(DateFilter(from: weekStart, to: todayEnd));
          },
        ),
        const SizedBox(width: 8),
        _chip(
          ref.t('filters.thisMonth'),
          selectedType == DateFilterType.month,
          () {
            ref.read(reportDateTypeProvider.notifier).set(DateFilterType.month);
            onChanged(DateFilter(from: monthStart, to: todayEnd));
          },
        ),
        const SizedBox(width: 8),
        _chip(ref.t('filters.allTime'), selectedType == DateFilterType.all, () {
          ref.read(reportDateTypeProvider.notifier).set(DateFilterType.all);
          onChanged(const DateFilter());
        }),
        const SizedBox(width: 12),
        IconButton(
          icon: Icon(
            Icons.calendar_month,
            color: selectedType == DateFilterType.custom
                ? const Color(0xFFD4AF37)
                : Colors.white54,
          ),
          tooltip: ref.t('reports.customRange'),
          onPressed: () async {
            // Sequential pickers for "auto-submit" behavior
            final fromDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              helpText: 'START DATE',
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFFD4AF37),
                  ),
                ),
                child: child!,
              ),
            );

            if (fromDate != null) {
              if (!context.mounted) return;
              final toDate = await showDatePicker(
                context: context,
                initialDate: fromDate,
                firstDate: fromDate,
                lastDate: DateTime.now().add(const Duration(days: 1)),
                helpText: 'END DATE',
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: Color(0xFFD4AF37),
                    ),
                  ),
                  child: child!,
                ),
              );

              if (toDate != null) {
                ref
                    .read(reportDateTypeProvider.notifier)
                    .set(DateFilterType.custom);
                onChanged(
                  DateFilter(
                    from: DateTime(fromDate.year, fromDate.month, fromDate.day),
                    to: DateTime(
                      toDate.year,
                      toDate.month,
                      toDate.day,
                    ).add(const Duration(days: 1)),
                  ),
                );
              }
            }
          },
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
    label: Text(label),
    selected: selected,
    selectedColor: const Color(0xFFD4AF37),
    onSelected: (_) => onTap(),
  );
}

// ── Common components ─────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final String title;
  final VoidCallback? onAdd;
  const _Header({required this.title, this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        if (onAdd != null)
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(ref.t('management.addNew')),
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
            ),
          ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  const _ReportCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
  });

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
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: color ?? Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final String symbol;
  final bool isTotal;
  final Color? color;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.symbol,
    this.isTotal = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w400,
              color: isTotal ? Colors.white : Colors.white70,
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)} $symbol',
            style: TextStyle(
              fontSize: isTotal ? 20 : 14,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
              color:
                  color ?? (isTotal ? const Color(0xFFD4AF37) : Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ReportMetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.05,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.zero,
            ),
            child: Icon(icon, color: const Color(0xFFD4AF37), size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 18, // Increased from 11
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(color: Colors.white10, thickness: 1),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _FormalDataTable extends StatelessWidget {
  final List<MapEntry<String, double>> data;
  final IconData icon;
  final Color iconColor;

  const _FormalDataTable({
    required this.data,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.05,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const SizedBox(width: 28), // Space for icon
                Expanded(
                  child: Text(
                    'ITEM / NAME',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.3),
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Text(
                  'AMOUNT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.3),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          ...data.map((e) {
            final isLast = data.last == e;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: iconColor.withOpacity(0.7)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${e.value.toStringAsFixed(2)} ETB',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) const Divider(height: 1, color: Colors.white10),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Charge Management ───────────────────────────────────────────────────

class ChargeManagementScreen extends ConsumerWidget {
  const ChargeManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chargesAsync = ref.watch(chargesListProvider);

    return Column(
      children: [
        _Header(
          title: ref.t('charges.dynamicTitle'),
          onAdd: () => _showChargeDialog(context, ref, null),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: chargesAsync.when(
            data: (charges) => GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: charges.length,
              itemBuilder: (ctx, i) {
                final charge = charges[i];
                return _ChargeCard(
                  charge: charge,
                  onEdit: () => _showChargeDialog(context, ref, charge),
                  onDelete: () =>
                      ref.read(chargesListProvider.notifier).delete(charge.id!),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('${ref.t('common.error')}: $e')),
          ),
        ),
      ],
    );
  }

  void _showChargeDialog(
    BuildContext context,
    WidgetRef ref,
    ChargeModel? charge,
  ) {
    final nameCtrl = TextEditingController(text: charge?.name);
    final valueCtrl = TextEditingController(text: charge?.value.toString());
    String type = charge?.type ?? 'addition';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            charge == null ? ref.t('charges.add') : ref.t('charges.edit'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: ref.t('charges.nameHint'),
                ),
              ),
              TextField(
                controller: valueCtrl,
                decoration: InputDecoration(
                  labelText: ref.t('charges.valueHint'),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: type,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: 'addition',
                    child: Text(ref.t('charges.addition')),
                  ),
                  DropdownMenuItem(
                    value: 'deduction',
                    child: Text(ref.t('charges.deduction')),
                  ),
                ],
                onChanged: (v) => setLocalState(() => type = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ref.t('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final newCharge = ChargeModel(
                  id: charge?.id,
                  name: nameCtrl.text,
                  type: type,
                  value: double.tryParse(valueCtrl.text) ?? 0.0,
                  isActive: charge?.isActive ?? true,
                );
                if (charge == null) {
                  ref.read(chargesListProvider.notifier).add(newCharge);
                } else {
                  ref.read(chargesListProvider.notifier).update(newCharge);
                }
                Navigator.pop(ctx);
              },
              child: Text(ref.t('common.save')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChargeCard extends StatelessWidget {
  final ChargeModel charge;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ChargeCard({
    required this.charge,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAddition = charge.type == 'addition';
    return GlassContainer(
      opacity: 0.05,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isAddition ? Colors.green : Colors.red).withOpacity(
                    0.1,
                  ),
                  borderRadius: BorderRadius.zero,
                ),
                child: Text(
                  charge.type.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isAddition ? Colors.green : Colors.red,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: Colors.white54,
                    ),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Text(
            charge.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            '${charge.value}%',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isAddition ? const Color(0xFFD4AF37) : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }
}
