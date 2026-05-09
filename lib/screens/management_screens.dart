import 'package:fl_chart/fl_chart.dart';
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
                _Header(
                  title: ref.t('management.products'),
                  onAdd: selectedCategoryId == null
                      ? null
                      : () => _showProductDialog(context, null),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: TextField(
                    onChanged: (val) =>
                        ref.read(productSearchProvider.notifier).set(val),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: ref.t('common.searchPlaceholder'),
                      hintStyle: const TextStyle(color: Colors.white24),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white38,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                Expanded(
                  child: productsAsync.when(
                    data: (products) {
                      final query = ref
                          .watch(productSearchProvider)
                          .toLowerCase();
                      final filtered = products
                          .where((p) => p.name.toLowerCase().contains(query))
                          .toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Opacity(
                            opacity: 0.4,
                            child: Text(ref.t('common.noResultsFound')),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final p = filtered[i];
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
                      );
                    },
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
      if (nameCtrl.text.trim().isEmpty || price == null) return;
      final repo = ref.read(posRepositoryProvider);
      try {
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
              categoryId: existing.categoryId,
              name: nameCtrl.text.trim(),
              price: price,
            ),
          );
        }
        ref.invalidate(productsProvider(selectedCategoryId));
        ref.invalidate(productsProvider(null));
        if (ctx.mounted) Navigator.pop(ctx);
      } catch (e) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
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
          width: 300,
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

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final orders = ref.watch(ordersProvider);
    final filter = ref.watch(reportDateFilterProvider);

    return GlassContainer(
      opacity: 0.05,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      ref.t('management.orders'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: TextField(
                        onChanged: (val) =>
                            ref.read(orderSearchProvider.notifier).set(val),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: ref.t('common.searchPlaceholder'),
                          hintStyle: const TextStyle(color: Colors.white24),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.white38,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    _DateFilterChips(
                      filter: filter,
                      onChanged: (f) {
                        ref.read(reportDateFilterProvider.notifier).set(f);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: orders.when(
              data: (list) {
                final query = ref.watch(orderSearchProvider).toLowerCase();
                final filtered = list.where((o) {
                  return o.id.toString().contains(query) ||
                      o.tableName.toLowerCase().contains(query) ||
                      o.waiterName.toLowerCase().contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Opacity(
                      opacity: 0.4,
                      child: Text(
                        query.isEmpty
                            ? ref.t('management.noOrdersInRange')
                            : ref.t('common.noResultsFound'),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final o = filtered[i];
                    final settings = ref.watch(appSettingsProvider).value ?? {};
                    final scPercent =
                        double.tryParse(
                          settings['service_charge_percent'] ?? '5',
                        ) ??
                        5;
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
                                final settings = await ref.read(
                                  cafeSettingsProvider.future,
                                );
                                BillService.generateAndDownloadBill(
                                  order: o,
                                  items: o.items,
                                  settings: settings,
                                  cashierName: o.cashierName,
                                  serviceChargePercent: scPercent,
                                  t: ref.t,
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
                          ref.read(dashboardViewProvider.notifier).state =
                              DashboardView.newOrder;
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
    final ordersAsync = ref.watch(ordersProvider);
    final analytics = ref.watch(reportAnalyticsProvider);
    final filter = ref.watch(reportDateFilterProvider);
    final waitersAsync = ref.watch(waitersProvider);
    final selectedWaiterId = ref.watch(reportWaiterFilterProvider);

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
              const SizedBox(width: 16),
              // Waiter filter dropdown
              waitersAsync.when(
                data: (waiters) => Container(
                  constraints: const BoxConstraints(maxWidth: 200),
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: selectedWaiterId,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1A1A1A),
                      hint: Text(
                        ref.t('management.allWaiters'),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            ref.t('management.allWaiters'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        ...waiters.map(
                          (w) => DropdownMenuItem<int?>(
                            value: w.id,
                            child: Text(
                              w.name,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          ref.read(reportWaiterFilterProvider.notifier).set(v),
                    ),
                  ),
                ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
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
          child: ordersAsync.when(
            data: (orderList) {
              if (analytics == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final completed = orderList
                  .where((o) => o.status == OrderStatus.completed)
                  .where(
                    (o) =>
                        selectedWaiterId == null ||
                        o.waiterId == selectedWaiterId,
                  )
                  .toList();

              if (completed.isEmpty) {
                return Center(
                  child: Opacity(
                    opacity: 0.4,
                    child: Text(ref.t('management.noOrdersInRange')),
                  ),
                );
              }

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
              final itemsSoldTotal = completed.fold(
                0,
                (s, o) => s + o.items.fold(0, (ss, i) => ss + i.quantity),
              );

              return ListView(
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  // KPI Cards
                  Row(
                    children: [
                      Expanded(
                        child: _StatSummaryCard(
                          title: ref.t('management.avgOrderValue'),
                          value:
                              '${analytics.avgOrderValue.toStringAsFixed(0)} ${ref.t('common.currency')}',
                          icon: Icons.receipt_long_outlined,
                          color: const Color(0xFFD4AF37),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatSummaryCard(
                          title: ref.t('management.mostSoldItem'),
                          value: analytics.mostSoldItem ?? '-',
                          icon: Icons.star_outline,
                          color: const Color(0xFF006B3C),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatSummaryCard(
                          title: ref.t('management.shiftSummary'),
                          value:
                              '${completed.length} ${ref.t('management.orders')}',
                          icon: Icons.timer_outlined,
                          color: const Color(0xFFC41E3A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
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
                        title: ref.t('management.subtotal'),
                        value:
                            '${subtotalSum.toStringAsFixed(2)} ${ref.t('common.currency')}',
                        icon: Icons.receipt_outlined,
                      ),
                      _ReportCard(
                        title: ref.t('management.serviceCharge'),
                        value:
                            '${serviceSum.toStringAsFixed(2)} ${ref.t('common.currency')}',
                        icon: Icons.room_service_outlined,
                      ),
                      _ReportCard(
                        title: ref.t('management.discountsGiven'),
                        value:
                            '${discountSum.toStringAsFixed(2)} ${ref.t('common.currency')}',
                        icon: Icons.discount_outlined,
                      ),
                      _ReportCard(
                        title: ref.t('management.grandTotal'),
                        value:
                            '${grandSum.toStringAsFixed(2)} ${ref.t('common.currency')}',
                        icon: Icons.trending_up,
                        color: const Color(0xFFD4AF37),
                      ),
                      _ReportCard(
                        title: ref.t('management.orderCount'),
                        value: '${completed.length}',
                        icon: Icons.shopping_bag_outlined,
                      ),
                      _ReportCard(
                        title: ref.t('management.itemsSold'),
                        value: '$itemsSoldTotal',
                        icon: Icons.inventory_2_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  // Charts
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _SectionHeader(
                              title: ref.t('management.categorySales'),
                              icon: Icons.pie_chart_outline,
                            ),
                            const SizedBox(height: 10),
                            _buildCategoryChart(
                              context,
                              analytics.categorySales,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: [
                            _SectionHeader(
                              title: ref.t('management.hourlySales'),
                              icon: Icons.show_chart,
                            ),
                            const SizedBox(height: 10),
                            _buildHourlyChart(context, analytics.hourlySales),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  _SectionHeader(
                    title: ref.t('management.topProducts'),
                    icon: Icons.star_outline,
                  ),
                  const SizedBox(height: 10),
                  _buildTopProductsTable(context, analytics.topProducts, ref),
                  const SizedBox(height: 40),
                  _SectionHeader(
                    title: ref.t('management.performance'),
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 10),
                  _buildWaiterPerformanceTable(
                    context,
                    analytics.waiterPerformance,
                    ref,
                  ),
                  const SizedBox(height: 40),
                  _SectionHeader(
                    title: ref.t('management.dailySales'),
                    icon: Icons.calendar_today_outlined,
                  ),
                  const SizedBox(height: 10),
                  _buildDailySalesTable(context, analytics.dailySales, ref),
                  const SizedBox(height: 40),
                  _SectionHeader(
                    title: ref.t('management.salesRecord'),
                    icon: Icons.list_alt_outlined,
                  ),
                  const SizedBox(height: 10),
                  _buildSalesRecordList(context, completed, ref),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),
        ),
      ],
    );
  }

  Widget _buildTopProductsTable(
    BuildContext context,
    Map<String, ({int qty, double revenue})> products,
    WidgetRef ref,
  ) {
    return GlassContainer(
      opacity: 0.05,
      child: Column(
        children:
            (products.entries.toList()
                  ..sort((a, b) => b.value.qty.compareTo(a.value.qty)))
                .take(10)
                .map(
                  (e) => ListTile(
                    dense: true,
                    title: Text(
                      e.key,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${ref.t('management.revenue')}: ${e.value.revenue.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white38,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${e.value.qty} ${ref.t('management.qtySold')}',
                        style: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildWaiterPerformanceTable(
    BuildContext context,
    Map<String, ({int orders, double revenue})> performance,
    WidgetRef ref,
  ) {
    return GlassContainer(
      opacity: 0.05,
      child: Column(
        children: performance.entries
            .map(
              (e) => ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF006B3C),
                  child: Icon(Icons.person, size: 18, color: Colors.white),
                ),
                title: Text(e.key),
                subtitle: Text(
                  '${e.value.orders} ${ref.t('management.orderCount')}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Text(
                  '${e.value.revenue.toStringAsFixed(2)} ${ref.t('common.currency')}',
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildDailySalesTable(
    BuildContext context,
    Map<String, double> dailySales,
    WidgetRef ref,
  ) {
    return GlassContainer(
      opacity: 0.05,
      child: Column(
        children:
            (dailySales.entries.toList()
                  ..sort((a, b) => b.key.compareTo(a.key)))
                .take(10)
                .map(
                  (e) => ListTile(
                    dense: true,
                    title: Text(e.key),
                    trailing: Text(
                      '${e.value.toStringAsFixed(2)} ${ref.t('common.currency')}',
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildSalesRecordList(
    BuildContext context,
    List<OrderModel> orders,
    WidgetRef ref,
  ) {
    return GlassContainer(
      opacity: 0.05,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: orders.length,
        separatorBuilder: (_, __) =>
            const Divider(color: Colors.white10, height: 1),
        itemBuilder: (_, i) {
          final o = orders[i];
          return ExpansionTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '#${o.id}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
            title: Text(
              o.tableName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              '${o.waiterName} • ${DateFormat('HH:mm').format(o.createdAt)}',
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
            trailing: Text(
              '${o.grandTotal.toStringAsFixed(2)} ${ref.t('common.currency')}',
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontWeight: FontWeight.bold,
              ),
            ),
            children: o.items
                .map(
                  (item) => ListTile(
                    dense: true,
                    title: Text(item.productName),
                    trailing: Text(
                      '${item.quantity} × ${item.unitPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _StatSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.05,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFD4AF37)),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Colors.white70,
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

    final isToday = filter.from == todayStart && filter.to == todayEnd;
    final isWeek = filter.from == weekStart && filter.to == todayEnd;
    final isMonth = filter.from == monthStart && filter.to == todayEnd;
    final isAll = filter.from == null && filter.to == null;
    final isCustom =
        !isToday &&
        !isWeek &&
        !isMonth &&
        !isAll &&
        (filter.from != null || filter.to != null);

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
        const SizedBox(width: 8),
        _chip(
          isCustom && filter.from != null && filter.to != null
              ? '${DateFormat('MMM d').format(filter.from!)} - ${DateFormat('MMM d').format(filter.to!.subtract(const Duration(days: 1)))}'
              : ref.t('filters.custom'),
          isCustom,
          () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 1)),
              initialDateRange: filter.from != null && filter.to != null
                  ? DateTimeRange(
                      start: filter.from!,
                      end: filter.to!.subtract(const Duration(days: 1)),
                    )
                  : null,
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFFD4AF37),
                    surface: Color(0xFF1A1A1A),
                    onSurface: Colors.white,
                  ),
                  dialogBackgroundColor: const Color(0xFF121212),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              onChanged(
                DateFilter(
                  from: picked.start,
                  to: picked.end.add(const Duration(days: 1)),
                ),
              );
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
    String? requiredFieldMessage,
  }) {
    final validationMsg = requiredFieldMessage ?? ref.t('common.fieldRequired');
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
            value == null || value.isEmpty ? validationMsg : null,
      ),
    );
  }
}

Widget _buildCategoryChart(BuildContext context, Map<String, double> data) {
  if (data.isEmpty)
    return const SizedBox(
      height: 200,
      child: Center(
        child: Text('No data', style: TextStyle(color: Colors.white38)),
      ),
    );

  final colors = [
    const Color(0xFFD4AF37),
    const Color(0xFF006B3C),
    const Color(0xFFC41E3A),
    const Color(0xFF0047AB),
    const Color(0xFF800080),
    const Color(0xFFE97451),
  ];

  return GlassContainer(
    opacity: 0.05,
    child: Container(
      height: 320,
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 50,
                sections: data.entries.toList().asMap().entries.map((e) {
                  final index = e.key;
                  final entry = e.value;
                  final isSmall =
                      entry.value < data.values.reduce((a, b) => a < b ? a : b);
                  return PieChartSectionData(
                    color: colors[index % colors.length],
                    value: entry.value,
                    title: entry.value >= 1
                        ? '${entry.key}\n${entry.value.toStringAsFixed(0)}'
                        : '',
                    radius: isSmall ? 70 : 85,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: data.entries.toList().asMap().entries.map((e) {
              final index = e.key;
              final entry = e.value;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[index % colors.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.key} (${entry.value.toStringAsFixed(0)})',
                    style: const TextStyle(fontSize: 10, color: Colors.white60),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    ),
  );
}

Widget _buildHourlyChart(BuildContext context, Map<int, double> data) {
  if (data.isEmpty)
    return const SizedBox(
      height: 200,
      child: Center(
        child: Text('No data', style: TextStyle(color: Colors.white38)),
      ),
    );

  final spots =
      data.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList()
        ..sort((a, b) => a.x.compareTo(b.x));

  return GlassContainer(
    opacity: 0.05,
    child: Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(24, 32, 32, 16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value % 3 != 0) return const SizedBox.shrink();
                  final h = value.toInt();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${h}:00',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFFD4AF37),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFFD4AF37).withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
