import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/models/category.dart';
import 'package:st_george_pos/models/product.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/locales/app_localizations.dart';
import 'package:st_george_pos/services/bill_service.dart';
import 'package:st_george_pos/core/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/screens/order_screen.dart';
import 'package:st_george_pos/models/charge.dart';

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
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: GlassContainer(
            opacity: 0.05,
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
                        label: const Text('Bulk Assign'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFD4AF37),
                        ),
                        onPressed: () => _showBulkAssignDialog(context, selectedCategoryId!),
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
                                onPressed: () => _showProductDialog(context, p),
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
        title: Text(
          existing == null
              ? 'ADD CATEGORIES (Batch)'
              : ref.t('common.edit'),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: existing == null ? 5 : 1,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: existing == null ? 'Category Names (One per line)' : ref.t('management.name'),
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
                final names = ctrl.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty);
                for (final name in names) {
                  await ref.read(posRepositoryProvider).addCategory(name);
                }
              } else {
                // Update logic if needed (repo needs update for category edit)
                await ref.read(posRepositoryProvider).addCategory(ctrl.text.trim());
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
    List<int> selectedIds = existing?.categoryIds ?? (selectedCategoryId != null ? [selectedCategoryId!] : []);

    Future<void> doSave(BuildContext ctx) async {
      final price = double.tryParse(priceCtrl.text);
      if (nameCtrl.text.trim().isEmpty || price == null || selectedIds.isEmpty) return;
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
                const Text('CATEGORIES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38)),
                const SizedBox(height: 8),
                Consumer(builder: (context, ref, _) {
                  final cats = ref.watch(categoriesProvider).value ?? [];
                  return Wrap(
                    spacing: 8,
                    children: cats.map((c) => FilterChip(
                      label: Text(c.name, style: const TextStyle(fontSize: 11)),
                      selected: selectedIds.contains(c.id),
                      onSelected: (val) {
                        setDialogState(() {
                          if (val) selectedIds.add(c.id!);
                          else selectedIds.remove(c.id);
                        });
                      },
                    )).toList(),
                  );
                }),
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
    final categoryProducts = allProducts.where((p) => p.categoryIds.contains(categoryId)).map((e) => e.id!).toSet();
    Set<int> selectedProductIds = Set.from(categoryProducts);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Bulk Assign to Category'),
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
                  title: Text(p.name, style: const TextStyle(color: Colors.white)),
                  activeColor: const Color(0xFFD4AF37),
                  checkColor: Colors.black,
                  side: const BorderSide(color: Colors.white54),
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == true) selectedProductIds.add(p.id!);
                      else selectedProductIds.remove(p.id!);
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
                    final newIds = List<int>.from(p.categoryIds)..add(categoryId);
                    await repo.updateProduct(p.copyWith(categoryIds: newIds));
                  } else if (!shouldBeInCategory && isInCategory) {
                    final newIds = List<int>.from(p.categoryIds)..remove(categoryId);
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

class WaiterManagementScreen extends ConsumerWidget {
  const WaiterManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final waitersAsync = ref.watch(waitersProvider);
    return GlassContainer(
      opacity: 0.05,
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => searchQuery = v),
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search by Waiter...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                        prefixIcon: Icon(Icons.search, size: 16, color: Colors.white.withOpacity(0.3)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                final filtered = list.where((o) => o.waiterName.toLowerCase().contains(searchQuery.toLowerCase())).toList();
                
                if (filtered.isEmpty) {
                  return Center(
                    child: Opacity(
                      opacity: 0.4,
                      child: Text(searchQuery.isEmpty ? ref.t('management.noOrdersInRange') : 'No matching orders for this waiter'),
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
                          replacements: {
                            'id': '${o.id}',
                            'table': o.tableName,
                          },
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
                                final settings = await ref.read(
                                  cafeSettingsProvider.future,
                                );
                                final charges = (await ref.read(chargesProvider.future))
                                    .where((c) => c.isActive)
                                    .toList();
                                await BillService.generateAndDownloadBill(
                                  order: o,
                                  items: o.items,
                                  settings: settings,
                                  cashierName: o.cashierName,
                                  activeCharges: charges,
                                  t: (key, {replacements}) =>
                                      AppLocalizations.getEnglish(key, replacements: replacements),
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
                                      item.notes != null &&
                                          item.notes!.isNotEmpty
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

class HeldOrdersScreen extends ConsumerWidget {
  const HeldOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: orders.when(
              data: (list) {
                final pending = list
                    .where((o) => o.status == OrderStatus.pending)
                    .toList();
                if (pending.isEmpty) {
                  return Center(
                    child: Opacity(
                      opacity: 0.4,
                      child: Text(ref.t('held.noHeldOrders')),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: pending.length,
                  itemBuilder: (_, i) {
                    final o = pending[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.white.withOpacity(0.05),
                      shape: RoundedRectangleBorder(
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
                          ref.read(dashboardViewProvider.notifier).state = DashboardView.pos;
                        },
                        title: Text(
                          ref.t(
                            'management.order',
                            replacements: {
                              'id': '${o.id}',
                              'table': o.tableName,
                            },
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
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

// ── Reports ───────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
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
              Text(
                ref.t('management.reports'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              _DateFilterChips(
                filter: filter,
                onChanged: (f) =>
                    ref.read(reportDateFilterProvider.notifier).set(f),
              ),
            ],
          ),
        ),
        Expanded(
          child: orders.when(
            data: (orderList) {
              final completed = orderList
                  .where((o) => o.status == OrderStatus.completed)
                  .toList();
              final subtotalSum = completed.fold(
                0.0,
                (s, o) => s + o.totalAmount,
              );
              final serviceSum = completed.fold(
                0.0,
                (s, o) => s + o.serviceCharge,
              );
              final discountSum = completed.fold(
                0.0,
                (s, o) => s + o.discountAmount,
              );
              final grandSum = completed.fold(0.0, (s, o) => s + o.grandTotal);
              final itemsSum = completed.fold(
                0,
                (s, o) => s + o.items.fold(0, (ss, i) => ss + i.quantity),
              );

              final vatRate = double.tryParse(ref.watch(appSettingsProvider).value?['cafe_vat_rate'] ?? '5.0') ?? 5.0;
              final vatSum = subtotalSum * (vatRate / 100);

              // Per-category
              final categoryMap = <String, double>{};
              for (final o in completed) {
                for (final item in o.items) {
                  // We don't have category name in OrderItem, but we can try to find it via product if needed.
                  // For now, let's group by product names if category is missing in model.
                }
              }

              // Per-waiter
              final waiterMap = <String, double>{};
              for (final o in completed) {
                waiterMap[o.waiterName] =
                    (waiterMap[o.waiterName] ?? 0) + o.grandTotal;
              }

              // Per-cashier
              final cashierMap = <String, double>{};
              for (final o in completed) {
                final name = o.cashierName.isNotEmpty
                    ? o.cashierName
                    : ref.t('management.unknown');
                cashierMap[name] = (cashierMap[name] ?? 0) + o.grandTotal;
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Formal Financial Summary ──────────────────────────
                    Text(
                      'FINANCIAL OVERVIEW',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassContainer(
                      opacity: 0.05,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _SummaryRow(
                            label: ref.t('management.subtotal'),
                            value: subtotalSum,
                            symbol: 'ETB',
                          ),
                          const Divider(height: 32, color: Colors.white10),
                          _SummaryRow(
                            label: ref.t('management.serviceCharge'),
                            value: serviceSum,
                            symbol: 'ETB',
                          ),
                          _SummaryRow(
                            label: ref.t('management.discountsGiven'),
                            value: -discountSum,
                            symbol: 'ETB',
                            color: Colors.redAccent.withOpacity(0.8),
                          ),
                          _SummaryRow(
                            label: 'ESTIMATED VAT ($vatRate%)',
                            value: vatSum,
                            symbol: 'ETB',
                            color: Colors.blueAccent.withOpacity(0.8),
                          ),
                          const Divider(height: 32, color: Colors.white10),
                          _SummaryRow(
                            label: ref.t('management.grandTotal'),
                            value: grandSum,
                            symbol: 'ETB',
                            isTotal: true,
                            color: const Color(0xFFD4AF37),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Performance Metrics Grid ──────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _ReportMetricCard(
                            title: ref.t('management.orderCount'),
                            value: '${completed.length}',
                            icon: Icons.receipt_long,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ReportMetricCard(
                            title: ref.t('management.itemsSold'),
                            value: '$itemsSum',
                            icon: Icons.inventory_2_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // ── Detailed Breakdowns ─────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // By Waiter
                        if (waiterMap.isNotEmpty)
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
                        if (waiterMap.isNotEmpty && cashierMap.isNotEmpty)
                          const SizedBox(width: 24),
                        // By Cashier
                        if (cashierMap.isNotEmpty)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionHeader(ref.t('management.byCashier')),
                                const SizedBox(height: 12),
                                _FormalDataTable(
                                  data: cashierMap.entries.toList(),
                                  icon: Icons.point_of_sale_outlined,
                                  iconColor: const Color(0xFFD4AF37),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('${ref.t('common.error')}: $e'),
          ),
        ),
      ],
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

    bool isToday = filter.from == todayStart && filter.to == todayEnd;
    bool isWeek = filter.from == weekStart && filter.to == todayEnd;
    bool isMonth = filter.from == monthStart && filter.to == todayEnd;
    bool isAll = filter.from == null && filter.to == null;

    return Row(
      children: [
        _chip(
          ref.t('filters.today'),
          isToday,
          () => onChanged(DateFilter(from: todayStart, to: todayEnd)),
        ),
        const SizedBox(width: 8),
        _chip(
          ref.t('filters.thisWeek'),
          isWeek,
          () => onChanged(DateFilter(from: weekStart, to: todayEnd)),
        ),
        const SizedBox(width: 8),
        _chip(
          ref.t('filters.thisMonth'),
          isMonth,
          () => onChanged(DateFilter(from: monthStart, to: todayEnd)),
        ),
        const SizedBox(width: 8),
        _chip(
          ref.t('filters.allTime'),
          isAll,
          () => onChanged(const DateFilter()),
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
                    Text(
                      ref.t('systemSettings.title'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSectionTitle(ref.t('settings.cafeInformation')),
                    _buildTextField(
                      ref.t('settings.cafeName'),
                      _nameController,
                      requiredFieldMessage: ref.t('common.fieldRequired'),
                    ),
                    _buildTextField(
                      ref.t('settings.address'),
                      _addressController,
                      requiredFieldMessage: ref.t('common.fieldRequired'),
                    ),
                    _buildTextField(
                      ref.t('settings.phoneNumber'),
                      _phoneController,
                      requiredFieldMessage: ref.t('common.fieldRequired'),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle(ref.t('settings.taxAndCurrency')),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            ref.t('settings.vatNumber'),
                            _vatNumberController,
                            requiredFieldMessage: ref.t('common.fieldRequired'),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildTextField(
                            ref.t('settings.vatRate'),
                            _vatRateController,
                            isNumber: true,
                            requiredFieldMessage: ref.t('common.fieldRequired'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    Center(
                      child: ElevatedButton(
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
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            final newSettings = settings.copyWith(
                              name: _nameController.text,
                              address: _addressController.text,
                              phone: _phoneController.text,
                              vatNumber: _vatNumberController.text,
                              vatRate:
                                  double.tryParse(_vatRateController.text) ??
                                  5.0,
                            );
                            await ref
                                .read(activeOrderServiceProvider)
                                .saveSettings(newSettings);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ref.t('systemSettings.settingsSaved'),
                                ),
                              ),
                            );
                          }
                        },
                        child: Text(
                          ref.t('systemSettings.saveChanges'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
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
      error: (e, _) => Center(child: Text('${ref.t('errors.error')}: $e')),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white38,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    String requiredFieldMessage = 'Field required',
  }) {
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: const BorderSide(color: Color(0xFFD4AF37)),
          ),
        ),
        validator: (value) =>
            value == null || value.isEmpty ? requiredFieldMessage : null,
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
              color: color ?? (isTotal ? const Color(0xFFD4AF37) : Colors.white),
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFD4AF37), size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
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
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: Colors.white.withOpacity(0.3),
      ),
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
        children: data.map((e) {
          final isLast = data.last == e;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: iconColor.withOpacity(0.7)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
        }).toList(),
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
          title: 'DYNAMIC CHARGES (ADDITIONS & DEDUCTIONS)',
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
                  onDelete: () => ref.read(chargesListProvider.notifier).delete(charge.id!),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  void _showChargeDialog(BuildContext context, WidgetRef ref, ChargeModel? charge) {
    final nameCtrl = TextEditingController(text: charge?.name);
    final valueCtrl = TextEditingController(text: charge?.value.toString());
    String type = charge?.type ?? 'addition';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(charge == null ? 'Add Charge' : 'Edit Charge'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name (e.g. VAT, Service)'),
              ),
              TextField(
                controller: valueCtrl,
                decoration: const InputDecoration(labelText: 'Value (%)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: type,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'addition', child: Text('Addition (+)')),
                  DropdownMenuItem(value: 'deduction', child: Text('Deduction (-)')),
                ],
                onChanged: (v) => setLocalState(() => type = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
              child: const Text('Save'),
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
                  color: (isAddition ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
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
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white54),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
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
