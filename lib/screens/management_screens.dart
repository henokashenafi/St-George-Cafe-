import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/models/category.dart';
import 'package:st_george_pos/models/product.dart';
import 'package:st_george_pos/models/waiter.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/locales/app_localizations.dart';
import 'package:st_george_pos/services/bill_service.dart';
import 'package:st_george_pos/core/database_helper.dart';
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
                Expanded(
                  child: productsAsync.when(
                    data: (products) => ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (_, i) {
                        final p = products[i];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.white10,
                            child: Icon(
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
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: ref.t('management.name'),
            labelStyle: TextStyle(color: Colors.white54),
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
              if (ctrl.text.trim().isEmpty) return;
              await ref
                  .read(posRepositoryProvider)
                  .addCategory(ctrl.text.trim());
              ref.invalidate(categoriesProvider);
              Navigator.pop(ctx);
            },
            child: Text(ref.t('common.save')),
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
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: ref.t('management.name'),
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: ref.t(
                    'management.priceLabel',
                    replacements: {'currency': ref.t('common.currency')},
                  ),
                  labelStyle: TextStyle(color: Colors.white54),
                ),
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
              final price = double.tryParse(priceCtrl.text);
              if (nameCtrl.text.trim().isEmpty || price == null) return;
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
                    categoryId: existing.categoryId,
                    name: nameCtrl.text.trim(),
                    price: price,
                  ),
                );
              }
              ref.invalidate(productsProvider(selectedCategoryId));
              ref.invalidate(productsProvider(null));
              Navigator.pop(ctx);
            },
            child: Text(ref.t('common.save')),
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
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFD4AF37),
                      child: Icon(Icons.person, color: Colors.black),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(ref.t('management.addWaiter')),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: ref.t('management.waiterNameLabel'),
            labelStyle: const TextStyle(color: Colors.white54),
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
              if (ctrl.text.trim().isNotEmpty) {
                await ref
                    .read(posRepositoryProvider)
                    .addWaiter(ctrl.text.trim());
                ref.refresh(waitersProvider);
                Navigator.pop(ctx);
              }
            },
            child: Text(ref.t('common.add')),
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
            child: Row(
              children: [
                Text(
                  ref.t('management.orders'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
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
            child: orders.when(
              data: (orderList) {
                if (orderList.isEmpty) {
                  return Center(
                    child: Opacity(
                      opacity: 0.4,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 56),
                          const SizedBox(height: 12),
                          Text(ref.t('management.noOrdersFound')),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: orderList.length,
                  itemBuilder: (_, i) {
                    final o = orderList[i];
                    final settings = ref.watch(settingsProvider).value ?? {};
                    final scPercent =
                        double.tryParse(
                          settings['service_charge_percent'] ?? '5',
                        ) ??
                        5;
                    return ExpansionTile(
                      title: Text(
                        ref.t(
                          'management.order',
                          replacements: {
                            'id': '${o.id}',
                            'table': '${o.tableName}',
                          },
                        ),
                      ),
                      subtitle: Text(
                        '${ref.t('management.waiter')}: ${o.waiterName}  |  ${ref.t('roles.cashier')}: ${o.cashierName}  |  ${DateFormat('dd/MM HH:mm').format(o.createdAt)}',
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
                              icon: const Icon(Icons.print_outlined),
                              tooltip: ref.t('management.reprintBill'),
                              onPressed: () =>
                                  BillService.generateAndDownloadBill(
                                    order: o,
                                    items: o.items,
                                    tableName: o.tableName,
                                    waiterName: o.waiterName,
                                    cashierName: o.cashierName,
                                    serviceCharge: o.serviceCharge,
                                    serviceChargePercent: scPercent,
                                    discountAmount: o.discountAmount,
                                    t: ref.t,
                                  ),
                            ),
                        ],
                      ),
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            ...o.items
                                .map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            item.productName,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            '${item.quantity} × ${item.unitPrice.toStringAsFixed(2)}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white38,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('${ref.t('common.error')}: $e'),
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
                          value: '$itemsSum',
                          icon: Icons.fastfood_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // Per-waiter
                    if (waiterMap.isNotEmpty) ...[
                      Text(
                        ref.t('management.byWaiter'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GlassContainer(
                        opacity: 0.05,
                        child: Column(
                          children: waiterMap.entries
                              .map(
                                (e) => ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFF006B3C),
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
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
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Per-cashier
                    if (cashierMap.isNotEmpty) ...[
                      Text(
                        ref.t('management.byCashier'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GlassContainer(
                        opacity: 0.05,
                        child: Column(
                          children: cashierMap.entries
                              .map(
                                (e) => ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFD4AF37),
                                    child: Icon(
                                      Icons.point_of_sale,
                                      color: Colors.black,
                                      size: 18,
                                    ),
                                  ),
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
                      ),
                    ],
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
