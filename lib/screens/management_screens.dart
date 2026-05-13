import 'package:flutter/material.dart'; // Reports Professionalization
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:toastification/toastification.dart';
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
import 'package:universal_html/html.dart' as html;
import 'package:intl/intl.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/screens/order_screen.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:st_george_pos/models/charge.dart';
import 'package:st_george_pos/models/shift.dart';
import 'package:st_george_pos/models/z_report.dart';
import 'package:st_george_pos/screens/table_management_screen.dart';

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback? onAdd;
  final VoidCallback? onClear;

  const _Header({required this.title, this.onAdd, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        Row(
          children: [
            if (onClear != null)
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 18),
                label: const Text('CLEAR', style: TextStyle(color: Colors.redAccent, fontSize: 10)),
              ),
            if (onAdd != null)
              IconButton(
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle, color: Color(0xFFD4AF37), size: 20),
              ),
          ],
        ),
      ],
    );
  }
}

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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    title: ref.t('management.categories'),
                    onAdd: () => _showCategoryDialog(context, null),
                    onClear: clearAllMenuData,
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    title: ref.t('management.products'),
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
          existing == null
              ? ref.t('management.addCategory')
              : ref.t('common.edit'),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: ref.t('management.name'),
            labelStyle: const TextStyle(color: Colors.white54),
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
            onPressed: () => doSave(ctx),
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

    Future<void> doSave(BuildContext ctx) async {
      final price = double.tryParse(priceCtrl.text);
      if (nameCtrl.text.trim().isEmpty ||
          price == null ||
          selectedCategoryId == null) return;
      final repo = ref.read(posRepositoryProvider);
      if (existing == null) {
        await repo.addProduct(
          Product(
            categoryId: selectedCategoryId!,
            name: nameCtrl.text.trim(),
            price: price,
          ),
        );
      } else {
        await repo.updateProduct(
          Product(
            id: existing.id,
            categoryId: selectedCategoryId!,
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
        content: SizedBox(
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
            onPressed: () => doSave(ctx),
            child: Text(ref.t('management.save')),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(int id) async {
    final catName = ref.read(categoriesProvider).value
        ?.firstWhere((c) => c.id == id, orElse: () => Category(id: id, name: ''))?.name ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
            const SizedBox(width: 8),
            Text(ref.t('common.deleteConfirmTitle')),
          ],
        ),
        content: Text(ref.t('reports.deleteCategoryConfirm', replacements: {'name': catName})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ref.t('common.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ref.t('common.delete')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(posRepositoryProvider).deleteCategory(id);
    ref.invalidate(categoriesProvider);
    ref.invalidate(productsProvider(null));
    if (selectedCategoryId == id) setState(() => selectedCategoryId = null);
  }

  void _deleteProduct(int id) async {
    final prodName = ref.read(productsProvider(selectedCategoryId)).value
        ?.firstWhere((p) => p.id == id, orElse: () => Product(id: id, categoryId: 0, name: '', price: 0))?.name ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
            const SizedBox(width: 8),
            Text(ref.t('common.deleteConfirmTitle')),
          ],
        ),
        content: Text(ref.t('reports.deleteProductConfirm', replacements: {'name': prodName})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ref.t('common.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ref.t('common.delete')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(posRepositoryProvider).deleteProduct(id);
    ref.invalidate(productsProvider(selectedCategoryId));
    ref.invalidate(productsProvider(null));
  }

  Future<void> clearAllMenuData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(ref.t('management.clearAllTitle') ?? 'WIPE ALL MENU DATA?'),
        content: Text(
          ref.t('management.clearAllConfirm') ??
              'This will permanently delete all products and categories. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ref.t('common.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ref.t('common.delete')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await ref.read(posRepositoryProvider).clearAllMenuData();
    ref.invalidate(categoriesProvider);
    ref.invalidate(productsProvider(null));
    if (selectedCategoryId != null) {
      ref.invalidate(productsProvider(selectedCategoryId));
      setState(() => selectedCategoryId = null);
    }
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
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1A1A1A),
                              title: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
                                  const SizedBox(width: 8),
                                  Text(ref.t('common.deleteConfirmTitle')),
                                ],
                              ),
                              content: Text(ref.t('reports.deleteWaiterConfirm', replacements: {'name': w.name})),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(ref.t('common.cancel')),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(ref.t('common.delete')),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;
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

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

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
    final ordersAsync = ref.watch(ordersProvider);
    final zReportsAsync = ref.watch(zReportsProvider);
    
    return ordersAsync.when(
      data: (allOrders) {
        final completed = allOrders.where((o) => o.status == OrderStatus.completed).toList();
        
        // --- Analysis Calculations ---
        final totalRevenue = completed.fold(0.0, (s, o) => s + o.grandTotal);
        final totalOrders = completed.length;
        final atv = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;
        
        // Hourly Sales Trend
        final hourlySales = List.generate(24, (_) => 0.0);
        for (final o in completed) {
          hourlySales[o.createdAt.hour] += o.grandTotal;
        }
        
        // Top Products
        final itemMap = <String, Map<String, dynamic>>{};
        for (final o in completed) {
          for (final it in o.items) {
            itemMap.putIfAbsent(it.productName, () => {'qty': 0, 'rev': 0.0, 'cat': it.categoryName});
            itemMap[it.productName]!['qty'] += it.quantity;
            itemMap[it.productName]!['rev'] += it.subtotal;
          }
        }
        final sortedItems = itemMap.entries.toList()
          ..sort((a, b) => (b.value['rev'] as double).compareTo(a.value['rev'] as double));
        final topItems = sortedItems.take(5).toList();

        // Category Share
        final catMap = <String, double>{};
        for (final o in completed) {
          for (final it in o.items) {
            final c = it.categoryName ?? 'General';
            catMap[c] = (catMap[c] ?? 0) + it.subtotal;
          }
        }
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, ref, completed),
              const SizedBox(height: 32),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- LEFT COLUMN: Metrics & Trends ---
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildKpiGrid(ref, totalRevenue, totalOrders, atv),
                        const SizedBox(height: 32),
                        _AnalysisCard(
                          title: 'HOURLY SALES TREND',
                          subtitle: 'Revenue distribution across the day',
                          child: _HourlySalesChart(hourlySales: hourlySales),
                        ),
                        const SizedBox(height: 32),
                        _AnalysisCard(
                          title: 'ORDER AUDIT',
                          subtitle: 'Most recent transactions',
                          child: _OrderAuditList(orders: completed),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  
                  // --- RIGHT COLUMN: Performance & Actions ---
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AnalysisCard(
                          title: 'TOP PERFORMING ITEMS',
                          subtitle: 'By revenue contribution',
                          child: _TopProductsAnalysis(items: topItems, totalRevenue: totalRevenue),
                        ),
                        const SizedBox(height: 32),
                        _AnalysisCard(
                          title: 'CATEGORY REVENUE SHARE',
                          subtitle: 'Distribution by category',
                          child: _CategoryShareAnalysis(catMap: catMap, totalRevenue: totalRevenue),
                        ),
                        const SizedBox(height: 32),
                        _QuickActionsSection(
                          pulseController: _pulseController,
                          onPrintX: () => _printFilteredReport(context, ref, allOrders, ref.read(reportDateFilterProvider)),
                          onExport: () => _exportToExcel(context, ref, allOrders, ref.read(reportDateFilterProvider)),
                        ),
                        const SizedBox(height: 32),
                        _AnalysisCard(
                          title: 'SHIFT ARCHIVE',
                          subtitle: 'Recent Z-Reports',
                          child: _ShiftArchivePreview(reportsAsync: zReportsAsync),
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
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, List<OrderModel> completed) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.t('management.reports').toUpperCase(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Color(0xFFD4AF37),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Business intelligence and shift analysis',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
            ),
          ],
        ),
        const Spacer(),
        _DateFilterChips(
          filter: ref.watch(reportDateFilterProvider),
          onChanged: (f) => ref.read(reportDateFilterProvider.notifier).set(f),
        ),
      ],
    );
  }

  Widget _buildKpiGrid(WidgetRef ref, double revenue, int orders, double atv) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.5,
      children: [
        _KpiCard(
          label: 'TOTAL REVENUE',
          value: '${revenue.toStringAsFixed(2)} ETB',
          icon: Icons.payments_outlined,
          color: const Color(0xFFD4AF37),
        ),
        _KpiCard(
          label: 'TOTAL ORDERS',
          value: '$orders',
          icon: Icons.receipt_outlined,
          color: Colors.blueAccent,
        ),
        _KpiCard(
          label: 'AVERAGE TICKET',
          value: '${atv.toStringAsFixed(2)} ETB',
          icon: Icons.analytics_outlined,
          color: Colors.greenAccent,
        ),
      ],
    );
  }

  void _printFilteredReport(
    BuildContext context,
    WidgetRef ref,
    List<OrderModel> allOrders,
    DateFilter filter,
  ) async {
    final completed = allOrders.where((o) => o.status == OrderStatus.completed).toList();

    if (completed.isEmpty) {
      toastification.show(
        context: context,
        title: const Text('No orders to print'),
        autoCloseDuration: const Duration(seconds: 3),
        type: ToastificationType.warning,
      );
      return;
    }

    final settings = await ref.read(posRepositoryProvider).getCafeSettings();
    final reportData = await ref.read(posRepositoryProvider).getShiftReportData(-1);

    final header = reportData['report_header'] as Map<String, dynamic>;
    header['opening_time'] = filter.from?.toIso8601String() ?? DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    header['closing_time'] = filter.to?.toIso8601String() ?? DateTime.now().toIso8601String();
    header['report_type'] = 'X REPORT (ANALYSIS)';

    reportData['orders_detail'] = completed.map((o) => {
      'id': o.id,
      'table_name': o.tableName,
      'waiter_name': o.waiterName,
      'cashier_name': o.cashierName,
      'created_at': o.createdAt.toIso8601String(),
      'grand_total': o.grandTotal,
      'items': o.items.map((i) => {
        'product_name': i.productName,
        'quantity': i.quantity,
        'unit_price': i.unitPrice,
        'subtotal': i.subtotal,
      }).toList(),
    }).toList();

    await BillService.printReport(reportData: reportData, settings: settings, isZReport: false);
  }

  void _exportToExcel(BuildContext context, WidgetRef ref, List<OrderModel> orders, DateFilter filter) async {
    final path = await ExportService.exportOrdersToExcel(orders, dateLabel: filter.label);
    if (path != null) {
      toastification.show(
        context: context,
        title: Text(kIsWeb ? 'Download Started' : 'Exported to Documents'),
        description: kIsWeb ? null : Text(path),
        autoCloseDuration: const Duration(seconds: 5),
        type: ToastificationType.success,
      );
    }
  }
}

// --- Minimalist Analysis Components ---

class _AnalysisCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _AnalysisCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.03,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white54)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.2))),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.05,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.3), letterSpacing: 1)),
                  const SizedBox(height: 4),
                  FittedBox(child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourlySalesChart extends StatelessWidget {
  final List<double> hourlySales;
  const _HourlySalesChart({required this.hourlySales});

  @override
  Widget build(BuildContext context) {
    final maxVal = hourlySales.reduce((a, b) => a > b ? a : b);
    
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(24, (i) {
          final heightFactor = maxVal > 0 ? hourlySales[i] / maxVal : 0.0;
          final isCurrentHour = DateTime.now().hour == i;
          
          return Expanded(
            child: Tooltip(
              message: '$i:00 - ${hourlySales[i].toStringAsFixed(2)} ETB',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: (120 * heightFactor).clamp(2, 120).toDouble(),
                    decoration: BoxDecoration(
                      color: isCurrentHour ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                    ),
                  ),
                  if (i % 4 == 0) ...[
                    const SizedBox(height: 8),
                    Text('$i', style: const TextStyle(fontSize: 9, color: Colors.white24)),
                  ] else const SizedBox(height: 17),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TopProductsAnalysis extends StatelessWidget {
  final List<MapEntry<String, Map<String, dynamic>>> items;
  final double totalRevenue;
  const _TopProductsAnalysis({required this.items, required this.totalRevenue});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text('No sales data', style: TextStyle(color: Colors.white24)));
    
    return Column(
      children: items.map((e) {
        final rev = e.value['rev'] as double;
        final share = totalRevenue > 0 ? rev / totalRevenue : 0.0;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text('${rev.toStringAsFixed(0)} ETB', style: const TextStyle(fontSize: 12, color: Color(0xFFD4AF37))),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  Container(height: 4, width: double.infinity, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
                  FractionallySizedBox(
                    widthFactor: share,
                    child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFD4AF37), borderRadius: BorderRadius.circular(2))),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CategoryShareAnalysis extends StatelessWidget {
  final Map<String, double> catMap;
  final double totalRevenue;
  const _CategoryShareAnalysis({required this.catMap, required this.totalRevenue});

  @override
  Widget build(BuildContext context) {
    final sorted = catMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    return Column(
      children: sorted.take(4).map((e) {
        final share = totalRevenue > 0 ? e.value / totalRevenue : 0.0;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(e.key, style: const TextStyle(fontSize: 12)),
          trailing: Text('${(share * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white54)),
        );
      }).toList(),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  final AnimationController pulseController;
  final VoidCallback onPrintX;
  final VoidCallback onExport;

  const _QuickActionsSection({required this.pulseController, required this.onPrintX, required this.onExport});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            FadeTransition(
              opacity: pulseController,
              child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFD4AF37), shape: BoxShape.circle)),
            ),
            const SizedBox(width: 8),
            const Text('LIVE OPERATIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onPrintX,
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('PRINT X-REPORT'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.table_chart_outlined, size: 18),
          label: const Text('EXPORT TO EXCEL'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }
}

class _ShiftArchivePreview extends StatelessWidget {
  final AsyncValue<List<ZReportModel>> reportsAsync;
  const _ShiftArchivePreview({required this.reportsAsync});

  @override
  Widget build(BuildContext context) {
    return reportsAsync.when(
      data: (reports) {
        if (reports.isEmpty) return const Text('No past shifts found', style: TextStyle(color: Colors.white24, fontSize: 12));
        return Column(
          children: reports.take(3).map((r) {
            final date = DateFormat('MMM dd, HH:mm').format(r.createdAt);
            final total = r.reportData['financials']?['grand_total'] ?? 0.0;
            
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.history, size: 16, color: Colors.white38),
              title: Text('Shift #${r.zCount}', style: const TextStyle(fontSize: 12)),
              subtitle: Text(date, style: const TextStyle(fontSize: 10, color: Colors.white24)),
              trailing: Text('${total.toStringAsFixed(0)} ETB', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            );
          }).toList(),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox(),
    );
  }
}

class _OrderAuditList extends StatelessWidget {
  final List<OrderModel> orders;
  const _OrderAuditList({required this.orders});

  @override
  Widget build(BuildContext context) {
    final recent = orders.reversed.take(10).toList();
    if (recent.isEmpty) return const Text('No orders yet', style: TextStyle(color: Colors.white24, fontSize: 12));
    
    return Column(
      children: [
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(1.5),
          },
          children: [
            const TableRow(
              children: [
                Text('ID', style: TextStyle(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.bold)),
                Text('TIME', style: TextStyle(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.bold)),
                Text('WAITER', style: TextStyle(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.bold)),
                Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.bold)),
              ],
            ),
            ...recent.map((o) => TableRow(
              children: [
                Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('#${o.id}', style: const TextStyle(fontSize: 11, color: Colors.white54))),
                Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(DateFormat('HH:mm').format(o.createdAt), style: const TextStyle(fontSize: 11, color: Colors.white54))),
                Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(o.waiterName, style: const TextStyle(fontSize: 11))),
                Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(o.grandTotal.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)))),
              ],
            )),
          ],
        ),
      ],
    );
  }
}

class _DateFilterChips extends StatelessWidget {
  final DateFilter filter;
  final Function(DateFilter) onChanged;

  const _DateFilterChips({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _filterChip('TODAY', DateFilter.today()),
        const SizedBox(width: 8),
        _filterChip('YESTERDAY', DateFilter.yesterday()),
        const SizedBox(width: 8),
        _filterChip('THIS WEEK', DateFilter.thisWeek()),
      ],
    );
  }

  Widget _filterChip(String label, DateFilter target) {
    final active = filter.label == target.label;
    return GestureDetector(
      onTap: () => onChanged(target),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? Colors.transparent : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: active ? Colors.black : Colors.white60,
          ),
        ),
      ),
    );
  }
}

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
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1A1A1A),
                        title: Text(ref.t('common.deleteConfirmTitle')),
                        content: Text(
                          ref.t(
                            'reports.deleteProductConfirm',
                            replacements: {'name': charge.name},
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(ref.t('common.cancel')),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(ref.t('common.delete')),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      ref.read(chargesListProvider.notifier).delete(charge.id!);
                    }
                  },
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

// ── Advanced Reporting Widgets ───────────────────────────────────────────



class _TablePerformanceSection extends StatelessWidget {
  final List<OrderModel> orders;
  const _TablePerformanceSection({required this.orders});

  @override
  Widget build(BuildContext context) {
    final tableStats = <String, Map<String, dynamic>>{};
    for (final o in orders) {
      tableStats.putIfAbsent(o.tableName, () => {'revenue': 0.0, 'count': 0});
      tableStats[o.tableName]!['revenue'] += o.grandTotal;
      tableStats[o.tableName]!['count'] += 1;
    }

    final sorted = tableStats.entries.toList()
      ..sort((a, b) => (b.value['revenue'] as double).compareTo(a.value['revenue'] as double));

    return Column(
      children: sorted.take(10).map((entry) {
        final revenue = entry.value['revenue'] as double;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Icon(Icons.table_restaurant_outlined, size: 16, color: const Color(0xFFD4AF37))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('${entry.value['count']} orders', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              Text('${revenue.toStringAsFixed(2)} ETB', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
            ],
          ),
        );
      }).toList(),
    );
  }
}

